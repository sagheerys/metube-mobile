part of 'mt_video_session.dart';

/// أوامر [MTVideoSession]: القفز والتخطي والوضع والسرعة.
///
/// **ملف `part`** (القاعدة 4 — حدّ الأسطر): الأوامر تمسّ الطابور الخاص
/// `_queue` و`_playMode`، فلا يصلح امتداد في مكتبة أخرى. والجلسة نفسها
/// تحتفظ بالتحميل ودورة الحياة — وهي جوهرها.
extension MTVideoSessionCommands on MTVideoSession {
  Future<void> seek(Duration to) async => _controller?.seekTo(to);

  /// نقرة مزدوجة يمين/يسار = ±١٠ ثوانٍ (مرجع المشغل العرضي).
  Future<void> seekBy(Duration delta) async {
    final controller = _controller;
    if (controller == null) return;
    final target = controller.value.position + delta;
    final max = controller.value.duration;
    await controller.seekTo(
      target < Duration.zero
          ? Duration.zero
          : (target > max ? max : target),
    );
  }

  Future<void> skipNext() => _move(forward: true);

  Future<void> skipPrevious() => _move(forward: false);

  Future<void> jumpTo(int itemIndex) async {
    await savePosition();
    if (!_queue.jumpTo(itemIndex)) return;
    await _load();
  }

  Future<void> _move({required bool forward}) async {
    await savePosition();
    final moved = forward
        ? _queue.moveNext(_playMode, userInitiated: true)
        : _queue.movePrevious(_playMode);
    if (moved) await _load();
  }

  Future<void> setPlayMode(PlayMode mode) async {
    _playMode = mode;
    await prefs.setPlayMode(mode, playlistId: _playlistId);
    notifyFromCommands();
  }

  Future<void> setShuffle(bool value) async {
    _queue.setShuffle(value);
    await prefs.setShuffle(value);
    notifyFromCommands();
  }

  Future<void> setSpeed(double speed) async {
    final value = PlaybackSpeeds.clamp(speed);
    await _controller?.setPlaybackSpeed(value);
    await prefs.setSpeed(value);
    notifyFromCommands();
  }

  /// **القِصار بلا استئناف (م-35 — العطل ط-4):** لا فحص `isShortForm`
  /// كان هنا إطلاقاً، فقائمة مختلطة تتقدم تلقائياً إلى مقطع قصير (أو
  /// قائمة تُفتح في `/player`) تكتب `playback_pos_<url>` لقصير —
  /// والريلز لا يمسحه أبداً لأنه لا يلمس مخزن المواضع: قيد ميت للأبد.
  Future<void> savePosition() async {
    final item = _queue.current;
    final controller = _controller;
    if (item == null || controller == null || !controller.value.isInitialized) {
      return;
    }
    if (item.isShortForm) return;
    await positions.save(
      item.canonicalUrl,
      controller.value.position,
      duration: controller.value.duration,
    );
  }

  /// **الإسكات أولاً ثم التصريف (العطل ط-2/3):** التصريف ليس فورياً،
  /// فكان صوت المقطعين يتداخل عند كل تخطٍّ — نفس الفخ الذي أُصلح في
  /// الريلز ولم ينل الجلسة.
  Future<void> _disposePlayers() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onTick);
      try {
        await controller.pause();
      } on Object {
        // متحكم مات قبلنا — التصريف تالياً يكفي.
      }
      await controller.dispose();
    }
    await _setWakelock(false);
  }

  /// إبقاء الشاشة مضاءة أثناء التشغيل فقط (م-20) — لا تُترك مفعّلة أبداً.
  Future<void> _setWakelock(bool enabled) async {
    if (_wakelockOn == enabled) return;
    _wakelockOn = enabled;
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on Object {
      // منصة بلا دعم ⇒ التشغيل يستمر بلا إبقاء الشاشة.
    }
  }
}
