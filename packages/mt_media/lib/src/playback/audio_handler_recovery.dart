part of 'audio_handler.dart';

/// **التعافي والاستمرار** — سياسة تخطي العنصر المعطوب، وحفظ الموضع
/// ولقطة الجلسة.
///
/// **ملف `part` لا مكتبة مستقلة** (القاعدة 4 — حدّ الأسطر): هذه الدوال
/// تعمل على الطابور الخاص (`_queue`، `_consecutiveErrors`)، وامتدادٌ في
/// مكتبة أخرى لا يصل للأعضاء الخاصة.
///
/// **ولا تُنقل هنا أي دالة تحمل `@override`:** الامتداد لا يتجاوز دالة
/// الأصل، وكان `audio_service` سينادي نسخة `BaseAudioHandler` بدلاً منها
/// — خطأ صحّة لا تنسيق (اكتُشف في الفحص الشامل 2026-09-02).
extension MTAudioHandlerRecovery on MTAudioHandler {
  /// أقصى تخطٍّ متتالٍ قبل الاستسلام — العطب المنهجي (شبكة مقطوعة أو
  /// cleartext محظور) يُفشل كل العناصر، فالمرور على مئة عنصر بصمت أسوأ
  /// من التوقف الصريح.
  static const int maxConsecutiveSkips = 5;

  /// تخطي تلقائي للعنصر المعطوب (م-21) — وإن تكرر العطب نتوقف بدل
  /// الدوران بلا نهاية.
  Future<void> _onError() async {
    _consecutiveErrors++;
    if (_queue.isEmpty ||
        _consecutiveErrors >= _queue.length ||
        _consecutiveErrors >= maxConsecutiveSkips) {
      return stop();
    }
    if (_queue.moveNext(PlayMode.repeatAll)) {
      await _loadCurrent(autoPlay: true);
    } else {
      await stop();
    }
  }

  void _publishQueue() =>
      queue.add([for (final item in _queue.ordered) item.toMediaItem()]);

  Future<void> savePosition() async {
    final item = _queue.current;
    if (item == null) return;
    await positions.save(
      item.canonicalUrl,
      player.position,
      duration: player.duration,
    );
  }

  /// حفظ دوري: الموضع + لقطة الجلسة (م-21).
  Future<void> persist() async {
    if (_queue.isEmpty) return;
    await savePosition();
    await stateStore.write(AudioSessionSnapshot(
      items: _queue.items,
      index: _queue.index,
      position: player.position,
      playlistId: _playlistId,
    ));
  }

}
