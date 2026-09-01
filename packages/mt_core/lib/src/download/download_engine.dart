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
import 'transfer.dart';

/// أين يُحفظ الملف المسحوب — يقررها التطبيق (Lite: Download/MeTube_Lite،
/// Super: مجلد «دون اتصال»).
typedef SavePathBuilder = String Function(
    DownloadTask task, String serverFilename);

/// محرك الخط الرباعي (§3): add ← poll ← pull ← delete(سياسة) —
/// تزامن أقصاه 1، أخطاء السيرفر تُفشِل **فوراً** (فخ §6.4)، والإلغاء
/// ينظف الجزئي. يبث كل تغير حالة عبر [updates].
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
  })  : _resolver = shortLinkResolver ?? ShortLinkResolver(),
        _transfer = transfer ?? Transfer(api: api);

  final MeTubeApi api;
  final DeletePolicy policy;
  final SavePathBuilder savePathBuilder;
  final Duration pollInterval;
  final int maxPollAttempts;

  /// ر-2: Lite يسحب للجهاز بعد الاكتمال؛ Super لا — العنصر يبقى على
  /// السيرفر ويظهر في المكتبة (السحب هناك عبر «إتاحة دون اتصال» فقط).
  final bool pullToDevice;

  /// للفهرسة بعد الاكتمال (OfflineIndex / MediaStore) في طبقة التطبيق.
  final void Function(DownloadTask task)? onCompleted;

  final ShortLinkResolver _resolver;
  final Transfer _transfer;
  final DownloadQueue _queue = DownloadQueue();
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _cancelRequested = {};
  final StreamController<DownloadTask> _updates =
      StreamController<DownloadTask>.broadcast();
  bool _working = false;

  Stream<DownloadTask> get updates => _updates.stream;
  List<DownloadTask> get tasks => List.unmodifiable(_tasks.values);
  DownloadTask? taskById(String id) => _tasks[id];

  /// إدخال مهمة — تُستخرج أول URL من نص المشاركة تلقائياً.
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
    unawaited(_pump());
    return task;
  }

  /// إلغاء: المنتظر يُعلَّم فوراً، والجاري يُقطع سحبه وتُحذف جزئياته.
  void cancel(String taskId) {
    _cancelRequested.add(taskId);
    if (_queue.remove(taskId)) {
      final task = _tasks[taskId];
      if (task != null) _emit(task.copyWith(phase: TaskPhase.cancelled));
      return;
    }
    _cancelTokens[taskId]?.cancel();
  }

  Future<void> dispose() async {
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    await _updates.close();
  }

  // ── العامل الواحد (تزامن = 1) ──

  Future<void> _pump() async {
    if (_working) return;
    _working = true;
    try {
      String? next;
      while ((next = _queue.takeNext()) != null) {
        await _run(next!);
      }
    } finally {
      _working = false;
    }
  }

  Future<void> _run(String taskId) async {
    var task = _tasks[taskId]!;
    if (_cancelRequested.contains(taskId)) {
      _emit(task.copyWith(phase: TaskPhase.cancelled));
      return;
    }
    try {
      // 1) الإضافة (حل الرابط القصير ثم /add — قاعدة الجودة داخل العميل)
      task = _emit(task.copyWith(phase: TaskPhase.adding));
      final resolved = await _resolver.resolve(task.inputUrl);
      task = _emit(task.copyWith(resolvedUrl: resolved));
      _throwIfCancelRequested(taskId);
      await api.add(resolved, task.quality);

      // 2) الاستطلاع حتى الاكتمال أو الخطأ الفوري
      task = _emit(task.copyWith(phase: TaskPhase.polling));
      final done = await _pollUntilDone(taskId, task);
      task = _emit(task.copyWith(
        canonicalUrl: done.canonicalUrl,
        serverFilename: done.filename,
      ));

      // Super: يكتفي ببقاء العنصر على السيرفر — لا سحب ولا حذف.
      if (!pullToDevice) {
        task = _emit(task.copyWith(phase: TaskPhase.completed, progress: 1));
        onCompleted?.call(task);
        return;
      }

      // 3) السحب
      task = _emit(task.copyWith(phase: TaskPhase.pulling, progress: 0));
      final savePath = savePathBuilder(task, done.filename!);
      final token = CancelToken();
      _cancelTokens[taskId] = token;
      if (_cancelRequested.contains(taskId)) token.cancel();
      await _transfer.pull(
        serverFilename: done.filename!,
        savePath: savePath,
        cancelToken: token,
        onProgress: (p) =>
            _emit(_tasks[taskId]!.copyWith(progress: p)),
      );
      task = _emit(_tasks[taskId]!.copyWith(localPath: savePath));

      // 4) الحذف حسب السياسة — بالـ canonicalUrl من /history حصراً
      if (policy == DeletePolicy.autoDelete) {
        task = _emit(task.copyWith(phase: TaskPhase.deleting));
        await api.delete([done.canonicalUrl]);
      }

      task = _emit(task.copyWith(phase: TaskPhase.completed, progress: 1));
      onCompleted?.call(task);
    } on CancelledException {
      _emit(_tasks[taskId]!.copyWith(phase: TaskPhase.cancelled));
    } on MTApiException catch (e) {
      _emit(_tasks[taskId]!.copyWith(phase: TaskPhase.failed, error: e));
    } finally {
      _cancelTokens.remove(taskId);
      _cancelRequested.remove(taskId);
    }
  }

  /// §2.3: كل [pollInterval] بحد [maxPollAttempts] — مطابقة ضبابية في
  /// done تلتقط filename وcanonicalUrl؛ حالة خطأ ⇒ فشل **فوري** مصنف؛
  /// filename غائب ⇒ ننتظر (لا يُخلَّق من العنوان أبداً — فخ §6.3).
  Future<HistoryItem> _pollUntilDone(String taskId, DownloadTask task) async {
    for (var attempt = 0; attempt < maxPollAttempts; attempt++) {
      _throwIfCancelRequested(taskId);
      final history = await api.fetchHistory();

      for (final item in [...history.done, ...history.active]) {
        if (!UrlKit.urlsMatch(item.canonicalUrl, task.effectiveUrl)) continue;
        if (item.hasError) {
          final detail = item.error ?? item.rawStatus;
          throw item.isPlatformBlocked
              ? PlatformBlockedException(detail)
              : ServerErrorException(detail);
        }
        if (item.isCompleted && item.filename != null) return item;
        if (item.progress != null) {
          _emit(_tasks[taskId]!.copyWith(progress: item.progress));
        }
      }

      if (attempt < maxPollAttempts - 1) {
        await Future<void>.delayed(pollInterval);
      }
    }
    throw const PollTimeoutException();
  }

  void _throwIfCancelRequested(String taskId) {
    if (_cancelRequested.contains(taskId)) {
      throw const CancelledException();
    }
  }

  DownloadTask _emit(DownloadTask task) {
    _tasks[task.id] = task;
    if (!_updates.isClosed) _updates.add(task);
    return task;
  }
}
