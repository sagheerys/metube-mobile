part of 'download_engine.dart';

/// **البثّ** — كل تغيّر حالة يمر من هنا إلى [DownloadEngine.updates].
///
/// ملف `part` لا مكتبة مستقلة (القاعدة 4 — حدّ الأسطر): هذه الدوال
/// تعمل على الحالة الخاصة للمحرك (`_tasks`، `_updates`، `_lastPercent`)،
/// وامتدادٌ في مكتبة أخرى لا يصل للأعضاء الخاصة.
extension DownloadEngineEmit on DownloadEngine {
  void _emitPhase(String taskId, TaskPhase phase) {
    _lastPercent.remove(taskId);
    final task = _tasks[taskId];
    if (task != null) _emit(task.copyWith(phase: phase));
  }

  /// **بثّ التقدّم عند تغيّر النسبة الصحيحة فقط** (بلاغ المالك
  /// 2026-09-04: «التطبيق ثقيل ولا يستجيب عند تحميل ٧ فيديوهات»،
  /// و«عداد الإشعارات لا يتحرك»).
  ///
  /// `onReceiveProgress` في Dio يُنادى **مع كل قطعة مستلمة** — مئات
  /// المرات في الثانية من سيرفر على الشبكة المحلية. كل نداء كان يمرّ
  /// بـ[_emit] ⇒ عنصر جديد في `updates` ⇒ إعادة بناء المكتبة كاملةً
  /// **ونشرُ إشعار لكل مهمة** في المراقب. سبع مهام متوازية تعني آلاف
  /// المنشورات في الدقيقة: أندرويد يخنق النشر فيتجمّد شريط الإشعار،
  /// والواجهة تتقطّع.
  ///
  /// النسبة الصحيحة سقفها 101 بثّة لكل مهمة في كل طور — والحالات غير
  /// التقدمية (تغيّر الطور، الاكتمال، الفشل) تمرّ بلا مرشّح إطلاقاً.
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
