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

/// جلسة مشغل الفيديو (م-20): تملك المتحكم والطابور والأوضاع، وتطبق
/// **القاعدة الذهبية** (م-19) في اختيار المصدر مثل مشغل الصوت تماماً،
/// وتتشارك معه مفتاح الموضع فيستأنف كلٌّ من حيث وقف الآخر (م-23).
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

  /// فتح قائمة في المشغل — القائمة المعروضة وقت النقر (ر-4 خطوة 1).
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

  Future<void> _load() async {
    final item = _queue.current;
    if (item == null) return;
    _loading = true;
    _error = null;
    notifyListeners();

    await _disposePlayers();
    final source = resolver.resolve(item);
    if (source == null) return _failCurrent();

    final controller = source.isLocal
        ? VideoPlayerController.file(File(source.uri.toFilePath()))
        : VideoPlayerController.networkUrl(source.uri,
            httpHeaders: source.headers);
    try {
      await controller.initialize();
    } on Object {
      await controller.dispose();
      return _failCurrent();
    }
    if (_disposed) return controller.dispose();

    _consecutiveErrors = 0;
    _controller = controller;
    final resume = await positions.positionOf(item.canonicalUrl);
    if (resume != null && resume < (controller.value.duration)) {
      await controller.seekTo(resume);
    }
    await controller.setPlaybackSpeed(await prefs.speed());
    controller.addListener(_onTick);
    await controller.play();
    _loading = false;
    notifyListeners();
    _rememberShape(item, controller);
  }

  /// المدة والنسبة تُعرفان بعد التحضير — تُحفظان في العنصر لمسار
  /// القِصار (م-35) في الجلسة الحالية.
  void _rememberShape(PlaylistItem item, VideoPlayerController controller) {
    final index = _queue.items.indexOf(item);
    if (index < 0) return;
    final value = controller.value;
    onShapeKnown?.call(
      item.canonicalUrl,
      value.duration,
      value.aspectRatio,
    );
  }

  /// يُبلَّغ الأعلى بأبعاد المقطع الحقيقية ليخزنها (م-35).
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
    if (value.duration > Duration.zero &&
        value.position >= value.duration &&
        !value.isPlaying) {
      unawaited(onCompleted());
    }
    notifyListeners();
  }

  // ── الأوامر ──

  Future<void> playPause() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      await savePosition();
    } else {
      await controller.play();
    }
    notifyListeners();
  }

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
    notifyListeners();
  }

  Future<void> setShuffle(bool value) async {
    _queue.setShuffle(value);
    await prefs.setShuffle(value);
    notifyListeners();
  }

  Future<void> setSpeed(double speed) async {
    final value = PlaybackSpeeds.clamp(speed);
    await _controller?.setPlaybackSpeed(value);
    await prefs.setSpeed(value);
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

  Future<void> savePosition() async {
    final item = _queue.current;
    final controller = _controller;
    if (item == null || controller == null || !controller.value.isInitialized) {
      return;
    }
    await positions.save(
      item.canonicalUrl,
      controller.value.position,
      duration: controller.value.duration,
    );
  }

  Future<void> _disposePlayers() async {
    _controller?.removeListener(_onTick);
    await _controller?.dispose();
    _controller = null;
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

  @override
  Future<void> dispose() async {
    _disposed = true;
    _saveTimer?.cancel();
    _saveTimer = null;
    await savePosition();
    await _disposePlayers();
    super.dispose();
  }
}
