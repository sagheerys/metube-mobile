import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// منصة `video_player` مزيّفة: تُبطئ التحضير عمداً لتفتح نافذة السباق
/// التي كانت تترك مشغلات يتيمة تعمل بالخلفية، وتحصي من يشتغل فعلاً.
class FakeVideoPlatform extends VideoPlayerPlatform {
  FakeVideoPlatform({this.createDelay = Duration.zero});

  /// زمن «التحضير» — على شبكة المالك كان يبلغ ثوانيَ لكل مقطع.
  Duration createDelay;

  int _next = 0;
  final Map<int, StreamController<VideoEvent>> _events = {};

  /// معرّفات المشغلات التي تشتغل الآن — أكثر من واحد = صوتان معاً.
  final Set<int> playing = {};

  /// ما أُنشئ ولم يُصرَّف بعد (كشف التسريب).
  final Set<int> alive = {};

  /// مصادر ما أُنشئ بالترتيب — للتأكد أي مقطع نجا من السباق.
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
    // الحدث يُبعث **عند أول اشتراك**: `initialize()` يشترك بعد `create`،
    // وبثّه قبلها يضيع في مجرى broadcast فيعلّق التحضير للأبد.
    late final StreamController<VideoEvent> controller;
    controller = StreamController<VideoEvent>.broadcast(onListen: () {
      scheduleMicrotask(() {
        if (controller.isClosed) return;
        controller.add(VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 30),
          size: const Size(1080, 1920), // عمودي: يدخل مسار القِصار
        ));
      });
    });
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

/// مشغل صوت وهمي يسجّل كم مرة طُلب إيقافه (حصرية المخرج).
class RecordingAudioPause {
  int calls = 0;

  Future<void> call() async => calls++;
}
