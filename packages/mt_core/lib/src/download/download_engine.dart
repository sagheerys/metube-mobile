import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;

import '../api/api_exceptions.dart';
import '../api/metube_api.dart';
import '../constants/mt_constants.dart';
import '../models/download_task.dart';
import '../models/history_item.dart';
import '../models/quality.dart';
import '../urls/short_link_resolver.dart';
import '../urls/url_kit.dart';
import 'delete_policy.dart';
import 'download_queue.dart';
import 'download_poller.dart';
import 'history_matcher.dart';
import 'pull_gate_parking.dart';
import 'transfer.dart';

part 'download_engine_pull.dart';

/// أين يُحفظ الملف المسحوب — يقررها التطبيق.
typedef SavePathBuilder = String Function(
    DownloadTask task, String serverFilename);

/// محرك الخط الرباعي (§3): add ← poll ← pull ← delete(سياسة) — تزامن
/// أقصاه 1، أخطاء السيرفر تُفشِل **فوراً** (فخ §6.4)، والإلغاء ينظف
/// الجزئي ويكنس يتيم السيرفر. يبث كل تغير حالة عبر [updates].
class DownloadEngine {
  DownloadEngine({
    required this.api,
    required this.policy,
    required this.savePathBuilder,
    ShortLinkResolver? shortLinkResolver,
    Transfer? transfer,
    this.pollInterval = MTConstants.pollInterval,
    this.maxPollAttempts = MTConstants.maxPollAttempts,
    this.pullToDevice = true,
    this.onCompleted,
    this.pullGate,
    this.onLog,
  })  : _resolver = shortLinkResolver ?? ShortLinkResolver(),
        _transfer = transfer ?? Transfer(api: api),
        _matcher = HistoryMatcher(api);

  final MeTubeApi api;
  final DeletePolicy policy;
  final SavePathBuilder savePathBuilder;
  final Duration pollInterval;
  final int maxPollAttempts;

  /// ر-2: Lite يسحب للجهاز بعد الاكتمال؛ Super لا (السحب هناك عبر
  /// «إتاحة دون اتصال» فقط).
  final bool pullToDevice;

  /// للفهرسة بعد الاكتمال (OfflineIndex / MediaStore).
  final void Function(DownloadTask task)? onCompleted;

  /// أثر تشخيصي (م-32) — mt_core لا يعرف مكان ملف السجل.
  final void Function(String message)? onLog;

  /// **بوابة السحب** (م-42 «Wi‑Fi فقط»): تُسأل قبل جلب الملف للجهاز.
  /// `false` ⇒ تُركن المهمة ([PullGateParking]) ويكمل الطابور. البوابة
  /// قبل السحب لا قبل الإضافة بقصد: الغالي هو الملف. والتطبيق هو من
  /// يجيب — mt_core لا يعرف `connectivity_plus` (القاعدة 6).
  final bool Function()? pullGate;

  final ShortLinkResolver _resolver;
  final Transfer _transfer;
  final HistoryMatcher _matcher;
  final DownloadQueue _queue = DownloadQueue();
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _cancelRequested = {};

  /// لقطة `/history` قبل الإضافة (ح-3) — وتميّز يتيم الإلغاء (ع-7).
  final Map<String, Set<String>> _snapshots = {};

  /// ما أوقفته بوابة الشبكة، بعنصر سجله جاهزاً للسحب (م-10).
  late final PullGateParking _parked = PullGateParking(
    pollInterval: pollInterval,
    onWake: () => unawaited(_pump()),
  );

  final StreamController<DownloadTask> _updates =
      StreamController<DownloadTask>.broadcast();
  bool _working = false;

  /// **علم الموت (ع-1):** بلا هذا تدور حلقات الاستطلاع والبوابة بعد
  /// التصريف على عميل Dio مغلق وتبثّ في stream مقفل.
  bool _disposed = false;

  Stream<DownloadTask> get updates => _updates.stream;
  List<DownloadTask> get tasks => List.unmodifiable(_tasks.values);
  DownloadTask? taskById(String id) => _tasks[id];

  /// هل ما زالت هناك مهمة حية؟ (يمنع تبديل السيرفر من إبادتها — ع-1)
  bool get hasActiveWork =>
      _tasks.values.any((t) => !t.isFinished) || _parked.isNotEmpty;

  /// إدخال مهمة — أول URL من نص المشاركة.
  DownloadTask submit(
    String url,
    Quality quality, {
    bool isBatchMember = false,
  }) {
    final task = DownloadTask(
      inputUrl: UrlKit.extractUrl(url),
      quality: quality,
      isBatchMember: isBatchMember,
    );
    _tasks[task.id] = task;
    _queue.enqueue(task.id, isBatchMember: isBatchMember);
    _emit(task);
    onLog?.call('submit ${task.quality.wire} ${task.inputUrl}');
    unawaited(_pump());
    return task;
  }

  /// إلغاء: المنتظر يُعلَّم فوراً، والجاري يُقطع سحبه وتُحذف جزئياته.
  void cancel(String taskId) {
    _cancelRequested.add(taskId);
    final task = _tasks[taskId];
    // في الطابور أو مركونة ⇒ لا عامل يمرّ عليها، فالإعلان والتنظيف هنا.
    if (_queue.remove(taskId) || _parked.remove(taskId)) {
      if (task != null) _emit(task.copyWith(phase: TaskPhase.cancelled));
      _cancelRequested.remove(taskId); // م-8: وإلا تسرّب للأبد
      unawaited(_cleanupOrphan(taskId));
      return;
    }
    _cancelTokens[taskId]?.cancel();
  }

  Future<void> dispose() async {
    _disposed = true;
    _parked.clear();
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    await _updates.close();
  }

  // ── العامل الواحد (تزامن = 1) ──

  Future<void> _pump() async {
    if (_working || _disposed) return;
    _working = true;
    try {
      while (!_disposed) {
        final resumed = _parked.takeIfOpen(() => pullGate?.call() ?? true);
        if (resumed != null) {
          final (id, item) = resumed;
          await _guard(id, () => _pullPhase(id, item));
          continue;
        }
        final next = _queue.takeNext();
        if (next == null) break;
        await _guard(next, () => _run(next));
      }
    } finally {
      _working = false;
    }
  }

  /// المعالجة الموحدة. **`on Object` الأخير هو إصلاح ع-2:** خطأ غير
  /// مصنف (`FileSystemException` من إعادة التسمية مثلاً) كان يهرب من
  /// المضخّة فتتجمد المهمة ويتوقف **الطابور كله** بلا رسالة.
  Future<void> _guard(String taskId, Future<void> Function() body) async {
    try {
      await body();
    } on CancelledException {
      _emitPhase(taskId, TaskPhase.cancelled);
      await _cleanupOrphan(taskId);
    } on MTApiException catch (e) {
      onLog?.call('task failed: $e');
      final task = _tasks[taskId];
      if (task != null) _emit(task.copyWith(phase: TaskPhase.failed, error: e));
    } on Object catch (e) {
      onLog?.call('task failed (local): $e');
      final task = _tasks[taskId];
      if (task != null) {
        _emit(task.copyWith(
            phase: TaskPhase.failed, error: LocalFailureException('$e')));
      }
    } finally {
      _cancelTokens.remove(taskId);
      _cancelRequested.remove(taskId);
    }
  }

  Future<void> _run(String taskId) async {
    var task = _tasks[taskId]!;
    if (_cancelRequested.contains(taskId)) {
      _emit(task.copyWith(phase: TaskPhase.cancelled));
      return;
    }
    // 1) الإضافة (حل الرابط القصير ثم /add)
    task = _emit(task.copyWith(phase: TaskPhase.adding));
    final resolved = await _resolver.resolve(task.inputUrl);
    task = _emit(task.copyWith(resolvedUrl: resolved));
    _throwIfCancelRequested(taskId);
    // ح-3: نعرف ما كان موجوداً قبلنا كي لا ننسب عملية غيرنا لأنفسنا.
    _snapshots[taskId] = await _matcher.snapshot(task.effectiveUrl);
    _throwIfCancelRequested(taskId);
    await api.add(resolved, task.quality);

    // 2) الاستطلاع حتى الاكتمال أو الخطأ الفوري
    task = _emit(task.copyWith(phase: TaskPhase.polling));
    final done = await _pollUntilDone(taskId, task);
    task = _emit(task.copyWith(
      canonicalUrl: done.canonicalUrl,
      serverFilename: done.filename,
      title: done.title,
      thumbnail: done.thumbnail,
    ));

    // Super: يكتفي ببقاء العنصر على السيرفر — لا سحب ولا حذف.
    if (!pullToDevice) {
      _complete(taskId);
      return;
    }

    // 3) بوابة مغلقة ⇒ **تُركن ويكمل الطابور** (م-10).
    if (!(pullGate?.call() ?? true)) {
      _parked.park(taskId, done);
      _emitPhase(taskId, TaskPhase.waitingForNetwork);
      return;
    }
    await _pullPhase(taskId, done);
  }

  /// استطلاع عنصر **هذه** المهمة — التفاصيل في [DownloadPoller].
  Future<HistoryItem> _pollUntilDone(String taskId, DownloadTask task) =>
      DownloadPoller(
        api: api,
        pollInterval: pollInterval,
        maxAttempts: maxPollAttempts,
      ).pollUntilDone(
        url: task.effectiveUrl,
        before: _snapshots[taskId] ?? const <String>{},
        checkAborted: () {
          if (_disposed) throw const CancelledException();
          _throwIfCancelRequested(taskId);
        },
        onProgress: (p) => _emit(_tasks[taskId]!.copyWith(progress: p)),
      );

  /// ع-7: ما أضافته مهمة أُلغيت لا يُترك على السيرفر.
  Future<void> _cleanupOrphan(String taskId) async {
    final task = _tasks[taskId];
    final before = _snapshots.remove(taskId);
    if (task == null || before == null || _disposed) return;
    if (task.localPath != null) return; // اكتمل السحب ⇒ ليس يتيماً
    await _matcher.deleteOrphan(task.effectiveUrl, before);
  }

  void _throwIfCancelRequested(String taskId) {
    if (_cancelRequested.contains(taskId)) {
      throw const CancelledException();
    }
  }

  void _emitPhase(String taskId, TaskPhase phase) {
    final task = _tasks[taskId];
    if (task != null) _emit(task.copyWith(phase: phase));
  }

  DownloadTask _emit(DownloadTask task) {
    _tasks[task.id] = task;
    if (!_updates.isClosed) _updates.add(task);
    return task;
  }
}
