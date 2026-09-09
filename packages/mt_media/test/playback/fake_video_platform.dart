import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A fake `video_player` platform: it delays preparation on purpose to open
/// the race window that used to leave orphaned players running in the
/// background, and it counts how many are actually playing.
class FakeVideoPlatform extends VideoPlayerPlatform {
  FakeVideoPlatform({this.createDelay = Duration.zero});

  /// The "preparation" time; on a real network it ran to seconds per clip.
  Duration createDelay;

  int _next = 0;
  final Map<int, StreamController<VideoEvent>> _events = {};

  /// The ids of the players running right now; more than one means two
  /// sounds at once.
  final Set<int> playing = {};

  /// What has been created and not yet disposed (leak detection).
  final Set<int> alive = {};

  /// The sources created, in order, to confirm which clip survived the
  /// race.
  final List<String> created = [];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final source = options.dataSource;
    if (createDelay > Duration.zero) await Future<void>.delayed(createDelay);
    final id = _next++;
    created.add(source.uri ?? source.asset ?? '');
    alive.add(id);
    // The event is emitted **on the first subscription**: `initialize()`
    // subscribes after `create`, and emitting before that is lost in the
    // broadcast stream, so preparation hangs forever.
    late final StreamController<VideoEvent> controller;
    controller = StreamController<VideoEvent>.broadcast(
      onListen: () {
        scheduleMicrotask(() {
          if (controller.isClosed) return;
          controller.add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: const Duration(seconds: 30),
              size: const Size(
                1080,
                1920,
              ), // portrait: it enters the shorts lane
            ),
          );
        });
      },
    );
    _events[id] = controller;
    return id;
  }

  @override
  Future<void> dispose(int playerId) async {
    playing.remove(playerId);
    alive.remove(playerId);
    await _events.remove(playerId)?.close();
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _events[playerId]?.stream ?? const Stream.empty();

  @override
  Future<void> play(int playerId) async => playing.add(playerId);

  @override
  Future<void> pause(int playerId) async => playing.remove(playerId);

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) => const SizedBox.shrink();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.shrink();
}

/// A fake audio player that records how many times it was asked to stop
/// (output exclusivity).
class RecordingAudioPause {
  int calls = 0;

  Future<void> call() async => calls++;
}
