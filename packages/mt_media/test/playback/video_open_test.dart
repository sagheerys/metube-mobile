import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/src/models/playback_source.dart';
import 'package:mt_media/src/video/mt_video_codec.dart';
import 'package:mt_media/src/video/mt_video_open.dart';
import 'package:video_player/video_player.dart';
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
    MTVideoCodec.reset();
    MTVideoCodec.readHead = (_) async => _head('avc1', 'avcC');
    platform = _RefusingPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() {
    MTVideoOpen.platformView = false;
    MTVideoCodec.reset();
  });

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

  // Field report 2026-10-16: the plugin's platform view reads the video
  // track as the player becomes ready and crashes the whole app when there
  // is none. A song in the video player (a mixed playlist) on a device that
  // had switched to the platform view took the app down.
  test(
    'a song opens on the texture even where clips use the platform view',
    () async {
      MTVideoOpen.platformView = true;
      final song = await MTVideoOpen.prepare(source, audioOnly: true);
      expect(song.viewType, VideoViewType.textureView);
      await song.dispose();

      MTVideoCodec.reset();
      MTVideoCodec.readHead = (_) async => _head('av01', 'av1C');
      final av1Song = await MTVideoOpen.prepare(source, audioOnly: true);
      expect(av1Song.viewType, VideoViewType.textureView);
      await av1Song.dispose();
    },
  );

  // Field report 2026-10-16: leaving full screen on a YouTube clip dimmed
  // over a player with no picture, then the picture popped in. The fade
  // showed the page beneath while the platform view was still away.
  test(
    'full screen opens and closes without a fade for a platform view',
    () async {
      Widget page(BuildContext _) => const SizedBox();
      MTVideoOpen.platformView = true;
      final av1 = await MTVideoOpen.prepare(source);
      final instant = mtFullscreenRoute(av1, page) as PageRoute<void>;
      expect(instant.transitionDuration, Duration.zero);
      expect(instant.reverseTransitionDuration, Duration.zero);
      await av1.dispose();

      MTVideoOpen.platformView = false;
      final texture = await MTVideoOpen.prepare(source);
      expect(mtFullscreenRoute(texture, page), isA<MaterialPageRoute<void>>());
      await texture.dispose();
    },
  );

  // Field report 2026-10-16, with a screen recording: leaving the player
  // for the library, the page faded and the AV1 picture did not. Android's
  // surface takes no part in a fade, so it stayed whole over a page that
  // was disappearing beneath it.
  for (final av1 in [true, false]) {
    testWidgets('leaving the player, ${av1 ? 'an AV1' : 'a texture'} picture '
        '${av1 ? 'steps aside' : 'fades with the page'}', (tester) async {
      MTVideoOpen.platformView = av1;
      final controller = (await tester.runAsync(
        () => MTVideoOpen.prepare(source),
      ))!;
      addTearDown(() => tester.runAsync(controller.dispose));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const SizedBox()),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => MTVideoView(controller)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VideoPlayer), findsOneWidget);

      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(VideoPlayer), av1 ? findsNothing : findsOneWidget);
      await tester.pumpAndSettle();
    });
  }

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

  group('AV1 opens in the platform view', () {
    // A flagship without AV1 in hardware drew these clips covered in green
    // dashes on the texture, with no error to catch.
    test('a WebM AV1 clip goes straight there, one attempt', () async {
      MTVideoCodec.readHead = (_) async => _head('V_AV1');
      final controller = await MTVideoOpen.prepare(source);
      expect(platform.views, [VideoViewType.platformView]);
      expect(
        MTVideoOpen.platformView,
        isFalse,
        reason: 'the next H.264 clip still gets the texture',
      );
      await controller.dispose();
    });

    test('an MP4 AV1 clip too', () async {
      MTVideoCodec.readHead = (_) async => _head('av01', 'av1C');
      await (await MTVideoOpen.prepare(source)).dispose();
      expect(platform.views, [VideoViewType.platformView]);
    });

    test('H.264 and VP9 keep the texture', () async {
      for (final head in [_head('avc1', 'avcC'), _head('V_VP9')]) {
        MTVideoCodec.reset();
        MTVideoCodec.readHead = (_) async => head;
        await (await MTVideoOpen.prepare(source)).dispose();
      }
      expect(platform.views, [
        VideoViewType.textureView,
        VideoViewType.textureView,
      ]);
    });

    test('a head that cannot be read opens as before', () async {
      MTVideoCodec.readHead = (_) async => throw const SocketException('down');
      await (await MTVideoOpen.prepare(source)).dispose();
      expect(platform.views, [VideoViewType.textureView]);
    });

    test('the answer is read once per clip', () async {
      var reads = 0;
      MTVideoCodec.readHead = (_) async {
        reads++;
        return _head('V_AV1');
      };
      await (await MTVideoOpen.prepare(source)).dispose();
      await (await MTVideoOpen.prepare(source)).dispose();
      expect(reads, 1);
    });

    test('four stray bytes in the picture do not pass for AV1', () {
      expect(MTVideoCodec.av1InHead(_head('av01')), isFalse);
      expect(MTVideoCodec.av1InHead(_head('av1C')), isFalse);
      expect(MTVideoCodec.av1InHead(_head('av01', 'av1C')), isTrue);
      expect(MTVideoCodec.av1InHead(const []), isFalse);
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

/// A file head with [markers] somewhere among filler bytes.
List<int> _head(String first, [String? second]) => [
  ...List.filled(40, 0),
  ...first.codeUnits,
  ...List.filled(40, 7),
  ...?second?.codeUnits,
  ...List.filled(40, 0),
];

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
