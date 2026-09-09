part of 'mt_reels_player.dart';

/// **Clip loading and playback commands** for the reels player.
///
/// **A `part` file rather than its own library** (rule 4, the size limit):
/// these functions work on private state (`_controller`, `_generation`,
/// `_disposed`), and an extension in another library cannot reach private
/// members. The screen itself keeps its lifecycle and its build, which are
/// its essence.
extension _ReelsPlayback on _MTReelsPlayerState {
  /// Silences the reel when the audio player asks for focus (defect ع-4),
  /// and releases the wake lock, since the clip is no longer being watched.
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

  /// Keeps the screen awake during playback only. It is never left enabled.
  Future<void> _setWakelock(bool enabled) async {
    if (_wakelockOn == enabled) return;
    _wakelockOn = enabled;
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on Object {
      // An unsupported platform: playback continues without keeping the
      // screen
      // awake.
    }
  }

  /// Shows the chrome and restarts the hide timer, which is cancelled while
  /// paused.
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

  /// Has a newer load overtaken us, or has the player died? Either way we
  /// touch no shared state afterwards.
  bool _stale(int generation) => _disposed || generation != _generation;

  Future<void> _load(int index) async {
    final generation = ++_generation;
    final item = index < widget.lane.length ? widget.lane.items[index] : null;
    final old = _controller;
    _controller = null;
    if (!_disposed) applyState(() => _failed = false);
    // Silence it first: `dispose()` may take a while, and the audio
    // continues
    // for the whole wait.
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
    // A newer swipe overtook us, so this controller is discarded rather
    // than
    // left running.
    if (_stale(generation)) return controller.dispose();
    await controller.setLooping(true); // يتكرر حتى السحب (م-35)
    await widget.onTakeAudioFocus?.call();
    if (_stale(generation)) return controller.dispose();
    await controller.play();
    // **The guard after the last `await` as well (defect ط-1):** the check
    // used to stop one line short of the end. Going back during `play()` on
    // a
    // slow network meant `setState` on a dead screen, **a live looping
    // controller nobody disposes, playing for the rest of the process's
    // life**, and a wake lock switched back on after leaving had switched
    // it
    // off.
    if (_stale(generation)) return controller.dispose();
    applyState(() => _controller = controller);
    await _setWakelock(true);
    // A new clip introduces itself and then withdraws: the title and the
    // uploader are read first.
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
    // Cancellation, when the vertical `PageView` wins the gesture, passes
    // through here too, or the clip stays paused with no visible pause
    // indicator.
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
    // After toggling: playing starts the hide timer, and pausing pins the
    // chrome.
    _showChrome();
  }
}

/// **Silence before disposal**: `dispose()` is not immediate on the
/// platform, and the audio continues for the whole wait. A top-level
/// function rather than a static member on an extension, since the latter
/// cannot be called unqualified from inside the class.
Future<void> _shutdownController(VideoPlayerController controller) async {
  try {
    await controller.pause();
  } on Object {
    // A controller that died before us; the disposal that follows is
    // enough.
  }
  try {
    await controller.dispose();
  } on Object {
    // No listener cares any more.
  }
}
