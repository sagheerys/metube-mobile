import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/play_mode.dart';
import '../models/playback_source.dart';
import '../models/playlist_item.dart';
import '../playback/playback_queue.dart';
import '../stores/playback_position_store.dart';
import '../stores/playback_prefs.dart';

part 'mt_video_session_commands.dart';

/// The video player session: it owns the controller, the queue and the
/// modes, applies **the golden rule** when choosing a source exactly as
/// the audio player does, and shares the position key with it, so each
/// resumes where the other stopped.
class MTVideoSession extends ChangeNotifier {
  MTVideoSession({
    required this.resolver,
    required this.positions,
    required this.prefs,
    Duration saveInterval = const Duration(seconds: 5),
  }) {
    _saveTimer = Timer.periodic(saveInterval, (_) => unawaited(savePosition()));
  }

  final PlaybackSourceResolver resolver;
  final PlaybackPositionStore positions;
  final PlaybackPrefs prefs;

  PlaybackQueue _queue = PlaybackQueue(items: const []);
  VideoPlayerController? _controller;
  PlayMode _playMode = PlayMode.autoNext;
  String? _playlistId;
  String? _error;
  bool _loading = false;
  bool _disposed = false;
  bool _wakelockOn = false;
  int _consecutiveErrors = 0;
  Timer? _saveTimer;

  /// **The completion latch:** the end condition stays true
  /// in every later notification from the controller, so `onCompleted` was
  /// called twice: two items skipped at once, **and the resume position of
  /// an item nobody had watched was cleared**.
  String? _completedUrl;

  /// **The race guard (caught on a real device 2026-09-01).** `_load`
  /// awaits `initialize()`, seconds on a slow network. A second skip during
  /// that wait starts a parallel load, the last to finish wins
  /// `_controller`, and **the first stays alive playing audio with no
  /// picture**: two clips at once.
  int _generation = 0;

  /// Called before any playback starts: it stops the background audio
  /// player so two sources never run together (one audio output at any
  /// moment).
  Future<void> Function()? onTakeAudioFocus;

  VideoPlayerController? get controller => _controller;
  PlaylistItem? get current => _queue.current;
  List<PlaylistItem> get items => _queue.items;
  List<PlaylistItem> get orderedItems => _queue.ordered;
  int get currentIndex => _queue.index;
  PlayMode get playMode => _playMode;
  bool get shuffleEnabled => _queue.shuffle;
  String? get playlistId => _playlistId;
  String? get error => _error;
  bool get isLoading => _loading;
  bool get isPlaying => _controller?.value.isPlaying ?? false;
  Duration get position => _controller?.value.position ?? Duration.zero;
  Duration? get duration => _controller?.value.duration;

  /// Opening a list in the player: the list shown at the moment of the tap
  /// (rule 4).
  Future<void> open(
    List<PlaylistItem> items, {
    int startIndex = 0,
    String? playlistId,
  }) async {
    if (items.isEmpty) return;
    _playlistId = playlistId;
    _playMode = await prefs.playMode(playlistId: playlistId);
    _consecutiveErrors = 0;
    _queue = PlaybackQueue(
      items: items,
      index: startIndex,
      shuffle: await prefs.shuffle(),
    );
    await _load();
  }

  /// `notifyListeners` is protected and cannot be called from an extension
  /// even in the same library. This is its only window into the commands
  /// `part` file.
  void notifyFromCommands() => notifyListeners();

  Future<void> _load() async {
    final item = _queue.current;
    if (item == null) return;
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();

    await _disposePlayers();
    final source = resolver.resolve(item);
    if (source == null) return _failCurrent();

    final controller = source.isLocal
        ? VideoPlayerController.file(File(source.uri.toFilePath()))
        : VideoPlayerController.networkUrl(
            source.uri,
            httpHeaders: source.headers,
          );
    try {
      await controller.initialize();
    } on Object {
      await controller.dispose();
      // **Publish after initialisation completes, not before.**
      // `_controller` was published and then three awaits followed
      // (position, seek, speed) with no guard between them: a second quick
      // skip disposed that very controller mid-way, so `seekTo` threw
      // "controller was used after being disposed".
      if (generation != _generation) return;
      return _failCurrent();
    }
    if (_disposed || generation != _generation) return controller.dispose();

    // **Publish after initialisation completes, not before.**
    // `_controller` was published and then three awaits followed
    // (position, seek, speed) with no guard between them: a second quick
    // skip disposed that very controller mid-way, so `seekTo` threw
    // "controller was used after being disposed".
    _consecutiveErrors = 0;
    _completedUrl = null;
    final resume = await positions.positionOf(item.canonicalUrl);
    if (_disposed || generation != _generation) return controller.dispose();
    if (resume != null && resume < (controller.value.duration)) {
      await controller.seekTo(resume);
    }
    await controller.setPlaybackSpeed(await prefs.speed());
    if (_disposed || generation != _generation) return controller.dispose();

    _controller = controller;
    controller.addListener(_onTick);
    await onTakeAudioFocus?.call();
    if (_disposed || generation != _generation) return;
    await controller.play();
    _loading = false;
    notifyListeners();
    _rememberShape(item, controller);
  }

  /// The duration and ratio become known after preparation and are stored
  /// on the item for the shorts path in the current session.
  void _rememberShape(PlaylistItem item, VideoPlayerController controller) {
    final index = _queue.items.indexOf(item);
    if (index < 0) return;
    final value = controller.value;
    onShapeKnown?.call(item.canonicalUrl, value.duration, value.aspectRatio);
  }

  /// The real clip dimensions are reported upwards to be stored.
  void Function(String canonicalUrl, Duration duration, double aspectRatio)?
  onShapeKnown;

  Future<void> _failCurrent() async {
    _consecutiveErrors++;
    _loading = false;
    if (_queue.isEmpty || _consecutiveErrors >= _queue.length) {
      _error = 'source';
      notifyListeners();
      return;
    }
    if (_queue.moveNext(PlayMode.repeatAll)) {
      await _load();
    } else {
      _error = 'source';
      notifyListeners();
    }
  }

  void _onTick() {
    final value = _controller?.value;
    if (value == null) return;
    if (value.hasError) {
      unawaited(_failCurrent());
      return;
    }
    unawaited(_setWakelock(value.isPlaying));
    final url = _queue.current?.canonicalUrl;
    if (value.duration > Duration.zero &&
        value.position >= value.duration &&
        !value.isPlaying &&
        url != null &&
        _completedUrl != url) {
      _completedUrl = url;
      unawaited(onCompleted());
    }
    notifyListeners();
  }

  // Commands.

  Future<void> playPause() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      await savePosition();
    } else {
      await onTakeAudioFocus?.call();
      await controller.play();
    }
    notifyListeners();
  }

  /// An explicit pause from above: "continue as audio" used to start the
  /// audio **while the video was still running**, so the clip was heard
  /// twice until the player closed, and on a slow network the overlap
  /// lasted several seconds.
  Future<void> pause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    await controller.pause();
    await savePosition();
    notifyListeners();
  }

  Future<void> onCompleted() async {
    final url = _queue.current?.canonicalUrl;
    if (url != null) await positions.clear(url);
    if (_playMode == PlayMode.repeatOne) {
      await _controller?.seekTo(Duration.zero);
      return _controller?.play();
    }
    if (_playMode != PlayMode.stopAtEnd && _queue.moveNext(_playMode)) {
      return _load();
    }
    await _controller?.pause();
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _generation++; // invalidates any pending load so no controller is published after death
    _saveTimer?.cancel();
    _saveTimer = null;
    // **Silence before saving:** between closing the screen
    // and the save completing, the video stayed **audible over the
    // library**; and a failed save prevented disposal entirely, so the
    // controller stayed alive.
    try {
      await _controller?.pause();
    } on Object {
      // Nothing to do; disposal follows anyway.
    }
    try {
      await savePosition();
    } on Object {
      // A failed save is no reason to leave a live controller behind us.
    }
    await _disposePlayers();
    super.dispose();
  }
}
