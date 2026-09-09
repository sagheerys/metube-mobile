part of 'download_engine.dart';

/// **The pull phase**: transferring to the device, then cleaning the
/// server according to policy.
///
/// **A `part` file rather than its own library** (rule 4, the size limit):
/// this phase works on the engine's private state (`_tasks`,
/// `_cancelTokens`, `_snapshots`), and an extension in another library
/// cannot reach private members.
extension DownloadEnginePull on DownloadEngine {
  /// Pull then delete, shared by the normal path and the one resumed after
  /// parking.
  Future<void> _pullPhase(String taskId, HistoryItem done) async {
    _throwIfCancelRequested(taskId);
    // The percentage resets with the phase: [_emitProgress] compares
    // against
    // the last percentage, so keeping the polling percentage swallowed the
    // first pull broadcast whenever the two numbers matched.
    _lastPercent.remove(taskId);
    _emit(_tasks[taskId]!.copyWith(phase: TaskPhase.pulling, progress: 0));
    final savePath = savePathBuilder(_tasks[taskId]!, done.filename!);
    final token = CancelToken();
    _cancelTokens[taskId] = token;
    if (_cancelRequested.contains(taskId)) token.cancel();
    // The final path comes from `pull`, not from what was requested: it may
    // shift on a collision (defect خ-3).
    final finalPath = await _transfer.pull(
      serverFilename: done.filename!,
      savePath: savePath,
      cancelToken: token,
      onProgress: (p) => _emitProgress(taskId, p),
    );
    _emit(_tasks[taskId]!.copyWith(localPath: finalPath));

    // 4) Delete by policy, using the canonicalUrl from /history and nothing
    // else. **Cleanup never undoes a completed transfer (defect ع-6):** a
    // failed delete used to mark the task "failed" and skip `onCompleted`,
    // so
    // the file stayed with no title index and no artwork.
    if (policy == DeletePolicy.autoDelete) {
      _emitPhase(taskId, TaskPhase.deleting);
      try {
        await api.delete([done.canonicalUrl]);
      } on MTApiException catch (e) {
        onLog?.call('server cleanup failed (file is safe): $e');
      }
    }
    _complete(taskId);
  }

  void _complete(String taskId) {
    final task =
        _emit(_tasks[taskId]!.copyWith(phase: TaskPhase.completed, progress: 1));
    _snapshots.remove(taskId);
    onLog?.call('completed ${task.title ?? task.effectiveUrl}');
    onCompleted?.call(task);
  }

}
