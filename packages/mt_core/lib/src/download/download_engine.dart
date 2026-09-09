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

part 'download_engine_emit.dart';
part 'download_engine_pull.dart';

/// Where the pulled file is saved. The app decides.
typedef SavePathBuilder = String Function(
  DownloadTask task,
  String serverFilename,
);

/// The four-stage engine (§3): add, poll, pull, delete-by-policy.
/// Concurrency of at most 1, server errors fail **immediately** (trap
/// §6.4), and cancelling cleans the partial file and sweeps the orphan it
/// left on the server. Every state change is broadcast through [updates].
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
    this.compatibleVideo,
    this.onLog,
  }) : _resolver = shortLinkResolver ?? ShortLinkResolver(),
       _transfer = transfer ?? Transfer(api: api),
       _matcher = HistoryMatcher(api);

  final MeTubeApi api;
  final DeletePolicy policy;
  final SavePathBuilder savePathBuilder;
  final Duration pollInterval;
  final int maxPollAttempts;

  /// Rule 2: Lite pulls to the device once an item completes; Super does
  /// not, where pulling happens only through "make available offline".
  final bool pullToDevice;

  /// A diagnostic trace: mt_core does not know where the log file lives.
  final void Function(DownloadTask task)? onCompleted;

  /// **The pull gate** ("Wi-Fi only"), asked before fetching a file to the
  /// device. `false` parks the task ([PullGateParking]) and the queue
  /// continues. The gate sits before the pull rather than before the add on
  /// purpose: the expensive part is the file. The app answers it, because
  /// mt_core does not know `connectivity_plus` (rule 6).
  final void Function(String message)? onLog;

  /// **The pull gate** ("Wi-Fi only"), asked before fetching a file to the
  /// device. `false` parks the task ([PullGateParking]) and the queue
  /// continues. The gate sits before the pull rather than before the add on
  /// purpose: the expensive part is the file. The app answers it, because
  /// mt_core does not know `connectivity_plus` (rule 6).
  final bool Function()? pullGate;

  /// **Playback compatibility** (field report 2026-09-03): asked on every
  /// add, requesting H.264/AAC instead of whatever the server picks (AV1 or
  /// VP9). See [MeTubeApiClient.add]. Read **at add time** like [pullGate],
  /// on purpose, so toggling the setting does not require rebuilding the
  /// engine.
  final bool Function()? compatibleVideo;

  final ShortLinkResolver _resolver;
  final Transfer _transfer;
  final HistoryMatcher _matcher;
  final DownloadQueue _queue = DownloadQueue();
  final Map<String, DownloadTask> _tasks = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _cancelRequested = {};

  /// The last **whole percentage** broadcast for each task, the filter used
  /// by [_emitProgress].
  final Map<String, Set<String>> _snapshots = {};

  /// The last **whole percentage** broadcast for each task, the filter used
  /// by [_emitProgress].
  final Map<String, int> _lastPercent = {};

  /// What the network gate stopped, with its history item ready to pull.
  late final PullGateParking _parked = PullGateParking(
    pollInterval: pollInterval,
    onWake: () => unawaited(_pump()),
  );

  final StreamController<DownloadTask> _updates =
      StreamController<DownloadTask>.broadcast();
  bool _working = false;

  /// **The death flag (defect ع-1):** without it, the polling and gate
  /// loops keep running after disposal, against a closed Dio client,
  /// emitting into a closed stream.
  bool _disposed = false;

  Stream<DownloadTask> get updates => _updates.stream;
  List<DownloadTask> get tasks => List.unmodifiable(_tasks.values);
  DownloadTask? taskById(String id) => _tasks[id];

  /// Is any task still alive? Stops a server switch from wiping them out
  /// (defect ع-1).
  bool get hasActiveWork =>
      _tasks.values.any((t) => !t.isFinished) || _parked.isNotEmpty;

  /// Enqueues a task, taking the first URL out of the shared text.
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

  /// Cancelling: a waiting task is marked at once, and a running one has
  /// its pull cut and its partial files deleted.
  void cancel(String taskId) {
    _cancelRequested.add(taskId);
    final task = _tasks[taskId];
    // Removes a **finished** task from the snapshot, for a failed card that
    // was resubmitted, so it does not linger beside the new attempt.
    // Running
    // tasks are untouched.
    if (_queue.remove(taskId) || _parked.remove(taskId)) {
      if (task != null) _emit(task.copyWith(phase: TaskPhase.cancelled));
      _cancelRequested.remove(taskId); // or it leaks forever
      unawaited(_cleanupOrphan(taskId));
      return;
    }
    _cancelTokens[taskId]?.cancel();
  }

  /// Removes a **finished** task from the snapshot, for a failed card that
  /// was resubmitted, so it does not linger beside the new attempt. Running
  /// tasks are untouched.
  void forget(String taskId) {
    final task = _tasks[taskId];
    if (task == null || !task.isFinished) return;
    _tasks.remove(taskId);
    _snapshots.remove(taskId);
    if (!_updates.isClosed) _updates.add(task);
  }

  Future<void> dispose() async {
    _disposed = true;
    _parked.clear();
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    await _updates.close();
  }

  // The single worker (concurrency 1).

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

  /// The unified handler. **The trailing `on Object` is the fix for defect
  /// ع-2:** an unclassified error, such as a `FileSystemException` from the
  /// rename, escaped the pump, so the task froze and **the whole queue**
  /// stopped with no message.
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
        _emit(
          task.copyWith(
            phase: TaskPhase.failed,
            error: LocalFailureException('$e'),
          ),
        );
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
    // 1) The add: resolve the short link, then call /add.
    task = _emit(task.copyWith(phase: TaskPhase.adding));
    final resolved = await _resolver.resolve(task.inputUrl);
    task = _emit(task.copyWith(resolvedUrl: resolved));
    _throwIfCancelRequested(taskId);
    // Defect ح-3: know what existed before us, so another operation is
    // never attributed to this task.
    _snapshots[taskId] = await _matcher.snapshot(task.effectiveUrl);
    _throwIfCancelRequested(taskId);
    await api.add(
      resolved,
      task.quality,
      compatibleVideo: compatibleVideo?.call() ?? false,
    );

    // 2) Poll until completion or an immediate error.
    task = _emit(task.copyWith(phase: TaskPhase.polling));
    final done = await _pollUntilDone(taskId, task);
    task = _emit(
      task.copyWith(
        canonicalUrl: done.canonicalUrl,
        serverFilename: done.filename,
        title: done.title,
        thumbnail: done.thumbnail,
      ),
    );

    // Super: leaving the item on the server is the whole job. No pull, no
    // delete.
    if (!pullToDevice) {
      _complete(taskId);
      return;
    }

    // 3) A closed gate **parks the task and the queue continues**.
    if (!(pullGate?.call() ?? true)) {
      _parked.park(taskId, done);
      _emitPhase(taskId, TaskPhase.waitingForNetwork);
      return;
    }
    await _pullPhase(taskId, done);
  }

  /// Polls the item belonging to **this** task; the details live in
  /// [DownloadPoller].
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
        onProgress: (p) => _emitProgress(taskId, p),
      );

  /// Defect ع-7: what a cancelled task added is not left on the server.
  Future<void> _cleanupOrphan(String taskId) async {
    final task = _tasks[taskId];
    final before = _snapshots.remove(taskId);
    if (task == null || before == null || _disposed) return;
    // The pull completed, so nothing was left orphaned on the server.
    if (task.localPath != null) return;
    await _matcher.deleteOrphan(task.effectiveUrl, before);
  }

  void _throwIfCancelRequested(String taskId) {
    if (_cancelRequested.contains(taskId)) {
      throw const CancelledException();
    }
  }
}
