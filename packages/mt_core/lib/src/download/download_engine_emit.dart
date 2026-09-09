part of 'download_engine.dart';

/// **Broadcasting.** Every state change passes through here on its way to
/// [DownloadEngine.updates].
///
/// A `part` file rather than its own library (rule 4, the size limit):
/// these functions work on the engine's private state (`_tasks`,
/// `_updates`, `_lastPercent`), and an extension in another library cannot
/// reach private members.
extension DownloadEngineEmit on DownloadEngine {
  void _emitPhase(String taskId, TaskPhase phase) {
    _lastPercent.remove(taskId);
    final task = _tasks[taskId];
    if (task != null) _emit(task.copyWith(phase: phase));
  }

  /// **Progress is broadcast only when the whole percentage changes**
  /// (field
  /// report 2026-09-04: "the app is heavy and unresponsive while
  /// downloading
  /// 7 videos", and "the notification counter does not move").
  ///
  /// Dio's `onReceiveProgress` fires **on every chunk received**, hundreds
  /// of times a second from a server on the local network. Each call went
  /// through [_emit], producing a new item in `updates`, rebuilding the
  /// whole library **and posting a notification per task** in the watcher.
  /// Seven parallel tasks meant thousands of posts a minute: Android
  /// throttles posting, the notification bar freezes and the interface
  /// stutters.
  ///
  /// A whole percentage caps this at 101 broadcasts per task per phase, and
  /// non-progress events (a phase change, completion, failure) pass with no
  /// filter at all.
  void _emitProgress(String taskId, double progress) {
    final task = _tasks[taskId];
    if (task == null) return;
    final percent = (progress.clamp(0, 1) * 100).floor();
    if (_lastPercent[taskId] == percent) return;
    _lastPercent[taskId] = percent;
    _emit(task.copyWith(progress: progress));
  }

  DownloadTask _emit(DownloadTask task) {
    _tasks[task.id] = task;
    if (!_updates.isClosed) _updates.add(task);
    return task;
  }
}
