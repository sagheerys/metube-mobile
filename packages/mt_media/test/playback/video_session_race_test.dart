import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **A regression: clips playing over each other** (field report
/// 2026-09-01).
///
/// `_load` awaits `initialize()`; a second skip during that wait started a
/// parallel load, and the last to finish won `_controller` **while the
/// first stayed alive playing audio with no picture**. And opening a video
/// while background audio played ran both sources together.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlatform platform;

  PlaylistItem item(String id) => PlaylistItem(
    canonicalUrl: 'https://x/$id',
    title: id,
    localPath: '/media/$id.mp4',
  );

  MTVideoSession build() {
    final store = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    return MTVideoSession(
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => true, // every file is local: no network in this test
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
    );
  }

  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  test('تخطٍّ أثناء التحضير ⇒ مشغل واحد فقط يشتغل ولا يتيم يبقى', () async {
    platform.createDelay = const Duration(milliseconds: 60);
    final session = build();
    addTearDown(session.dispose);

    // Open, then skip immediately: the skip lands before the first
    // preparation has finished.
    final opening = session.open([item('a'), item('b'), item('c')]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final skipping = session.skipNext();
    await Future.wait([opening, skipping]);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(
      platform.playing.length,
      1,
      reason: 'أكثر من مشغل يعمل = صوتان معاً (الخلل الأصلي)',
    );
    expect(
      platform.alive.length,
      1,
      reason: 'المشغل المتخلّى عنه يجب أن يُصرَّف',
    );
    expect(session.current!.title, 'b');
  });

  test('ثلاث تخطيات متتالية سريعة ⇒ يبقى واحد', () async {
    platform.createDelay = const Duration(milliseconds: 40);
    final session = build();
    addTearDown(session.dispose);

    final futures = [
      session.open([item('a'), item('b'), item('c'), item('d')]),
      for (var i = 0; i < 3; i++) session.skipNext(),
    ];
    await Future.wait(futures);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(platform.playing.length, 1);
    expect(platform.alive.length, 1);
  });

  test('بدء الفيديو يوقف الصوت الخلفي (مخرج واحد)', () async {
    final session = build();
    addTearDown(session.dispose);
    final pause = RecordingAudioPause();
    session.onTakeAudioFocus = pause.call;

    await session.open([item('a')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(pause.calls, greaterThanOrEqualTo(1));
    expect(platform.playing.length, 1);
  });

  test('pause() الصريح يوقف الفيديو — «متابعة صوتاً» بلا تداخل', () async {
    final session = build();
    addTearDown(session.dispose);

    await session.open([item('a')]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(platform.playing, isNotEmpty);

    await session.pause();
    expect(platform.playing, isEmpty);
  });
}
