part of 'mt_reels_player.dart';

/// **تحميل المقطع وأوامر التشغيل** لمشغل الريلز.
///
/// **ملف `part` لا مكتبة مستقلة** (القاعدة 4 — حدّ الأسطر): هذه الدوال
/// تعمل على حالة خاصة (`_controller`، `_generation`، `_disposed`)،
/// وامتدادٌ في مكتبة أخرى لا يصل للأعضاء الخاصة. الشاشة نفسها تحتفظ
/// بدورة الحياة والبناء — وهما جوهرها.
extension _ReelsPlayback on _MTReelsPlayerState {
  /// إسكات الريل حين يطلب مشغل الصوت التركيز (ع-4) — مع إطفاء قفل
  /// الشاشة، فالمقطع لم يعد يُشاهَد.
  Future<void> _pauseForAudioFocus() async {
    final controller = _controller;
    if (_disposed || controller == null || !controller.value.isPlaying) return;
    await controller.pause();
    await _setWakelock(false);
    if (!_disposed) {
      applyState(() {});
      _showChrome();
    }
  }

  /// إبقاء الشاشة مضاءة أثناء التشغيل فقط — لا تُترك مفعّلة أبداً.
  Future<void> _setWakelock(bool enabled) async {
    if (_wakelockOn == enabled) return;
    _wakelockOn = enabled;
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on Object {
      // منصة بلا دعم ⇒ التشغيل يستمر بلا إبقاء الشاشة.
    }
  }

  /// إظهار الأدوات وإعادة تشغيل مؤقت الاختفاء (يُلغى إن كان متوقفاً).
  void _showChrome() {
    _hideTimer?.cancel();
    if (_disposed) return;
    if (!_chrome) applyState(() => _chrome = true);
    if (_controller?.value.isPlaying ?? false) {
      _hideTimer = Timer(_MTReelsPlayerState._chromeLinger, () {
        if (!_disposed) applyState(() => _chrome = false);
      });
    }
  }

  /// هل سبقنا تحميلٌ أحدث — أو مات المشغل؟ ⇒ لا نلمس حالة مشتركة بعدها.
  bool _stale(int generation) => _disposed || generation != _generation;

  Future<void> _load(int index) async {
    final generation = ++_generation;
    final item = index < widget.lane.length ? widget.lane.items[index] : null;
    final old = _controller;
    _controller = null;
    if (!_disposed) applyState(() => _failed = false);
    // إسكاته أولاً: `dispose()` قد ينتظر، والصوت يستمر طوال الانتظار.
    if (old != null) await _shutdownController(old);
    if (item == null) return;

    final source = widget.resolver.resolve(item);
    if (source == null) {
      if (!_stale(generation)) applyState(() => _failed = true);
      return;
    }
    final controller = source.origin == PlaybackOrigin.local
        ? VideoPlayerController.file(File(source.uri.toFilePath()))
        : VideoPlayerController.networkUrl(source.uri,
            httpHeaders: source.headers);
    try {
      await controller.initialize();
    } on Object {
      await controller.dispose();
      if (!_stale(generation)) applyState(() => _failed = true);
      return;
    }
    // سحبة أحدث سبقتنا ⇒ نتخلص من هذا المتحكم بدل أن نتركه يعمل.
    if (_stale(generation)) return controller.dispose();
    await controller.setLooping(true); // يتكرر حتى السحب (م-35)
    await widget.onTakeAudioFocus?.call();
    if (_stale(generation)) return controller.dispose();
    await controller.play();
    // **الحارس بعد آخر `await` أيضاً (العطل ط-1):** كان الفحص يقف سطراً
    // واحداً قبل النهاية. رجوعٌ أثناء `play()` على شبكة بطيئة يعني:
    // `setState` على شاشة ميتة، **ومتحكم مُفعّل عليه التكرار لا يصرّفه
    // أحد فيعزف في حلقة لبقية عمر العملية**، وقفل شاشة يُعاد إشعاله بعد
    // أن أطفأه الخروج.
    if (_stale(generation)) return controller.dispose();
    applyState(() => _controller = controller);
    await _setWakelock(true);
    // المقطع الجديد يعرّف بنفسه ثم ينسحب: العنوان والناشر يُقرآن أولاً.
    _showChrome();
  }

  void _onScrubStart() {
    final controller = _controller;
    if (_disposed || controller == null) return;
    _resumeAfterScrub = controller.value.isPlaying;
    unawaited(controller.pause());
    unawaited(_setWakelock(false));
    _showChrome();
  }

  Future<void> _onScrubEnd() async {
    final controller = _controller;
    // الإلغاء (غلبة `PageView` العمودي على السحب) يمرّ من هنا أيضاً،
    // وإلا بقي المقطع موقوفاً بلا أي مؤشر إيقاف ظاهر.
    if (_disposed || controller == null || !_resumeAfterScrub) return;
    _resumeAfterScrub = false;
    await widget.onTakeAudioFocus?.call();
    if (_disposed) return;
    await controller.play();
    await _setWakelock(true);
    _showChrome();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (_disposed || controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      await _setWakelock(false);
    } else {
      await widget.onTakeAudioFocus?.call();
      await controller.play();
      await _setWakelock(true);
    }
    if (_disposed) return;
    applyState(() {});
    // بعد قلب الحالة: التشغيل يبدأ مؤقت الاختفاء، والإيقاف يثبّت الأدوات.
    _showChrome();
  }
}

/// **الإسكات قبل التصريف**: `dispose()` ليس فورياً على المنصة، والصوت
/// يستمر طوال انتظاره. دالة عليا لا عضو ساكن في امتداد — الأخير لا
/// يُنادى بلا تأهيل من داخل الصنف.
Future<void> _shutdownController(VideoPlayerController controller) async {
  try {
    await controller.pause();
  } on Object {
    // متحكم مات قبلنا — التصريف تالياً يكفي.
  }
  try {
    await controller.dispose();
  } on Object {
    // لا مستمع يهمه بعد الآن.
  }
}
