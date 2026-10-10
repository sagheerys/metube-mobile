import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/src/models/playback_source.dart';
import 'package:mt_media/src/video/mt_video_open.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **A decoder that refuses the texture path (2026-10-10)**: on an Android
/// 10 MediaTek tablet every H.264 clip failed to start, in the shorts and
/// in the player, while the same clip played in a platform view.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _RefusingPlatform platform;

  setUp(() {
    MTVideoOpen.platformView = false;
    platform = _RefusingPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() => MTVideoOpen.platformView = false);

  final source = PlaybackSource(
    origin: PlaybackOrigin.stream,
    uri: Uri.parse('https://srv/download/clip.mp4'),
  );

  test('a device that works keeps the texture, one attempt', () async {
    final controller = await MTVideoOpen.prepare(source);
    expect(controller.viewType, VideoViewType.textureView);
    expect(platform.views, [VideoViewType.textureView]);
    expect(MTVideoOpen.platformView, isFalse);
    await controller.dispose();
  });

  test('a refused decoder retries in a platform view and remembers', () async {
    platform.refuseTexture = true;
    final first = await MTVideoOpen.prepare(source);
    expect(first.value.isInitialized, isTrue);
    expect(first.viewType, VideoViewType.platformView);
    expect(platform.views, [
      VideoViewType.textureView,
      VideoViewType.platformView,
    ]);
    expect(platform.alive, hasLength(1), reason: 'the failed one is freed');

    // The next clip goes straight to the surface that works.
    final second = await MTVideoOpen.prepare(source);
    expect(platform.views.last, VideoViewType.platformView);
    expect(platform.views, hasLength(3));
    await first.dispose();
    await second.dispose();
  });

  test('a network error is not retried: a surface cannot fix it', () async {
    platform.failWith = 'Source error';
    await expectLater(
      MTVideoOpen.prepare(source),
      throwsA(isA<PlatformException>()),
    );
    expect(platform.views, [VideoViewType.textureView]);
    expect(MTVideoOpen.platformView, isFalse);
    expect(platform.alive, isEmpty);
  });

  test('a clip no surface can play leaves a healthy device as it was', () {
    // A flagship meeting a file its decoder does not support: both
    // attempts fail, and the next clip must still open on the texture.
    platform.failWith = 'MediaCodecVideoRenderer error, format unsupported';
    return expectLater(
      MTVideoOpen.prepare(source),
      throwsA(isA<PlatformException>()),
    ).then((_) {
      expect(platform.views, [
        VideoViewType.textureView,
        VideoViewType.platformView,
      ]);
      expect(MTVideoOpen.platformView, isFalse);
      expect(platform.alive, isEmpty);
    });
  });

  test('the message the tablet logged is recognised', () {
    final logged = PlatformException(
      code: 'VideoError',
      message:
          'Video player had error androidx.media3.exoplayer.'
          'ExoPlaybackException: MediaCodecVideoRenderer error, index=0',
    );
    expect(MTVideoOpen.refusedSurface(logged), isTrue);
    expect(
      MTVideoOpen.refusedSurface(
        PlatformException(code: 'VideoError', message: 'Source error'),
      ),
      isFalse,
    );
  });
}

/// Fails preparation the way the tablet did: the texture is refused with
/// the decoder's error, a platform view prepares normally.
class _RefusingPlatform extends FakeVideoPlatform {
  bool refuseTexture = false;
  String? failWith;
  final List<VideoViewType> views = [];
  final Map<int, String> _failure = {};

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    views.add(options.viewType);
    final id = await super.createWithOptions(options);
    final message =
        failWith ??
        (refuseTexture && options.viewType == VideoViewType.textureView
            ? 'ExoPlaybackException: MediaCodecVideoRenderer error'
            : null);
    if (message != null) _failure[id!] = message;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final message = _failure[playerId];
    if (message == null) return super.videoEventsFor(playerId);
    late final StreamController<VideoEvent> events;
    events = StreamController<VideoEvent>(
      onListen: () => scheduleMicrotask(
        () => events.addError(
          PlatformException(code: 'VideoError', message: message),
        ),
      ),
    );
    return events.stream;
  }
}
