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
  ///
  /// **[autoPlay] يُورَّث من المسار الذي استدعانا (إصلاح ع-5):** كان
  /// مثبّتاً على `true`، فإن تعذّر أول عناصر الجلسة المستعادة عند
  /// الإقلاع (ملف حُذف، سيرفر غير متاح لحظتها) **بدأ العنصر التالي
  /// يعزف بصوت مسموع بلا أي نقرة** — خرقاً لقاعدة م-21 «الاستعادة بلا
  /// تشغيل تلقائي».
  Future<void> _onError({bool autoPlay = true}) async {
    _consecutiveErrors++;
    if (_queue.isEmpty ||
        _consecutiveErrors >= _queue.length ||
        _consecutiveErrors >= maxConsecutiveSkips) {
      return stop();
    }
    if (_queue.moveNext(PlayMode.repeatAll)) {
      await _loadCurrent(autoPlay: autoPlay);
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

  Future<void> _loadCurrent({
    required bool autoPlay,
    Duration? startAt,
  }) async {
    final generation = ++_generation;
    final item = _queue.current;
    if (item == null) return stop();
    final source = resolver.resolve(item);
    if (source == null) return _onError(autoPlay: autoPlay);

    mediaItem.add(item.toMediaItem());
    final resume = startAt ??
        await positions.positionOf(item.canonicalUrl) ??
        Duration.zero;
    if (_isStale(generation)) return;
    try {
      if (autoPlay) await onTakeVideoFocus?.call();
      if (_isStale(generation)) return;
      await player.setSource(source, initialPosition: resume);
      if (_isStale(generation)) return;
      _consecutiveErrors = 0;
      final duration = player.duration;
      if (duration != null) {
        mediaItem.add(item.toMediaItem().copyWith(duration: duration));
      }
      if (autoPlay) await player.play();
      if (_isStale(generation)) return;
      _broadcast();
      await persist();
    } on Object {
      if (_isStale(generation)) return;
      await _onError(autoPlay: autoPlay);
    }
  }

  /// هل سبقنا تحميلٌ أحدث (أو إيقاف)؟ ⇒ لا نلمس حالة مشتركة بعدها.
  bool _isStale(int generation) => generation != _generation;
}
