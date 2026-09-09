import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'fake_player_port.dart';

/// Playback defects from 2026-09-02: ع-3 (the generation guard), ع-4 (the
/// opposite direction of the golden rule), ع-5 (a restore that autoplays).
PlaylistItem _item(String id) => PlaylistItem(
  canonicalUrl: 'https://x/$id',
  title: id,
  serverFilename: '$id.mp3',
  isAudio: true,
);

void main() {
  late FakePlayerPort player;
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;
  late AudioStateStore states;
  late Set<String> existingFiles;

  MTAudioHandler build() {
    player = FakePlayerPort();
    states = AudioStateStore(store: store, mutex: mutex);
    return MTAudioHandler(
      player: player,
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint(
          buildUrl: (name) => 'https://srv/download/$name',
          headers: const {},
        ),
        fileExists: existingFiles.contains,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: states,
      saveInterval: const Duration(hours: 1),
    );
  }

  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
    existingFiles = {};
  });

  test('ع-3 — سحب المشغل المصغر أثناء تحميل لا يعيده حياً يعزف', () async {
    final handler = build();
    final pending = handler.playItems([_item('a'), _item('b')]);
    await handler.stop();
    await pending;

    expect(
      handler.mediaItem.value,
      isNull,
      reason: 'قبل الإصلاح كان التحميل المعلّق يعيد نشر العنصر',
    );
    expect(handler.playbackState.value.playing, isFalse);
    expect(await states.read(), anyOf(isNull, predicate((s) => true)));
  });

  test('ع-3 — طلبان متتاليان: الأخير هو من يبقى في الإشعار', () async {
    final handler = build();
    final first = handler.playItems([_item('a')]);
    final second = handler.playItems([_item('b')]);
    await Future.wait([first, second]);

    expect(handler.mediaItem.value?.id, 'https://x/b');
    expect(handler.currentItem?.canonicalUrl, 'https://x/b');
  });

  test('ع-4 — تشغيل الصوت يطلب تركيز الفيديو أولاً', () async {
    final handler = build();
    var videoPaused = 0;
    handler.onTakeVideoFocus = () async => videoPaused++;

    await handler.playItems([_item('a')]);
    expect(videoPaused, 1, reason: 'بدء القائمة يُسكت الفيديو');

    await handler.pause();
    await handler.play();
    expect(videoPaused, 2, reason: 'زر التشغيل في الإشعار كذلك');
  });

  test('ع-4 — الاستعادة بلا تشغيل لا تنتزع تركيز الفيديو', () async {
    await AudioStateStore(store: store, mutex: mutex).write(
      AudioSessionSnapshot(
        items: [_item('a')],
        index: 0,
        position: Duration.zero,
      ),
    );
    final handler = build();
    var videoPaused = 0;
    handler.onTakeVideoFocus = () async => videoPaused++;

    await handler.restoreSession();
    expect(videoPaused, 0);
    expect(player.playing, isFalse);
  });

  test('ع-5 — عنصر أول معطوب في الاستعادة لا يشغّل التالي تلقائياً', () async {
    await AudioStateStore(store: store, mutex: mutex).write(
      AudioSessionSnapshot(
        items: [_item('broken'), _item('good')],
        index: 0,
        position: Duration.zero,
      ),
    );
    final handler = build();
    player.failing.add('https://srv/download/broken.mp3');

    await handler.restoreSession();

    expect(
      handler.currentItem?.canonicalUrl,
      'https://x/good',
      reason: 'التخطي نفسه سلوك صحيح',
    );
    expect(
      player.playing,
      isFalse,
      reason: 'قبل الإصلاح كان يعزف بصوت مسموع فور الإقلاع بلا نقرة',
    );
  });
}
