part of 'mt_video_session.dart';

/// [MTVideoSession] commands: seeking, skipping, mode and speed.
///
/// **A `part` file** (rule 4, the size limit): the commands touch the
/// private `_queue` and `_playMode`, so an extension in another library
/// will not do. The session itself keeps loading and the lifecycle, which
/// are its essence.
extension MTVideoSessionCommands on MTVideoSession {
  Future<void> seek(Duration to) async => _controller?.seekTo(to);

  /// A double tap on the right or left seeks ten seconds, from the
  /// landscape player reference.
  Future<void> seekBy(Duration delta) async {
    final controller = _controller;
    if (controller == null) return;
    final target = controller.value.position + delta;
    final max = controller.value.duration;
    await controller.seekTo(
      target < Duration.zero ? Duration.zero : (target > max ? max : target),
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

  /// **Shorts have no resume position (defect ط-4):** there was no
  /// `isShortForm` check here at all, so a mixed list advancing
  /// automatically
  /// into a short clip, or a list opened at `/player`, wrote
  /// `playback_pos_<url>` for a short. Reels never clears it, because it
  /// does
  /// not touch the position store: a dead entry forever.
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

  /// **Silence first, then dispose (defect ط-2/3):** disposal is not
  /// immediate, so the audio of two clips overlapped on every skip. The
  /// same trap that was fixed in reels and never reached the session.
  Future<void> _disposePlayers() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onTick);
      try {
        await controller.pause();
      } on Object {
        // A controller that died before us; the disposal that follows is
        // enough.
      }
      await controller.dispose();
    }
    await _setWakelock(false);
  }

  /// Keeps the screen awake during playback only. It is never left enabled.
  Future<void> _setWakelock(bool enabled) async {
    if (_wakelockOn == enabled) return;
    _wakelockOn = enabled;
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on Object {
      // An unsupported platform: playback continues without keeping the
      // screen awake.
    }
  }
}
