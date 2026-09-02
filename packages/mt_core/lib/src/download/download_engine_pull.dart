part of 'download_engine.dart';

/// **مرحلة السحب** — النقل إلى الجهاز ثم تنظيف السيرفر حسب السياسة.
///
/// **ملف `part` لا مكتبة مستقلة** (القاعدة 4 — حدّ الأسطر): هذه المرحلة
/// تعمل على الحالة الخاصة للمحرك (`_tasks`، `_cancelTokens`،
/// `_snapshots`)، وامتدادٌ في مكتبة أخرى لا يصل للأعضاء الخاصة.
extension DownloadEnginePull on DownloadEngine {
  /// السحب ثم الحذف — مشترك بين المسار العادي والمستأنف بعد الركن.
  Future<void> _pullPhase(String taskId, HistoryItem done) async {
    _throwIfCancelRequested(taskId);
    _emit(_tasks[taskId]!.copyWith(phase: TaskPhase.pulling, progress: 0));
    final savePath = savePathBuilder(_tasks[taskId]!, done.filename!);
    final token = CancelToken();
    _cancelTokens[taskId] = token;
    if (_cancelRequested.contains(taskId)) token.cancel();
    // المسار النهائي من `pull` لا المطلوب — قد يُزاح عند التصادم (خ-3).
    final finalPath = await _transfer.pull(
      serverFilename: done.filename!,
      savePath: savePath,
      cancelToken: token,
      onProgress: (p) => _emit(_tasks[taskId]!.copyWith(progress: p)),
    );
    _emit(_tasks[taskId]!.copyWith(localPath: finalPath));

    // 4) الحذف حسب السياسة — بالـ canonicalUrl من /history حصراً.
    // **التنظيف لا يُلغي نقلاً تمّ (ع-6):** فشل الحذف كان يعلّم المهمة
    // «فاشلة» ويمنع `onCompleted` فيبقى الملف بلا فهرسة عنوان ولا غلاف.
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
