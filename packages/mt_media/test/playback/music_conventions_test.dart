import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'fake_player_port.dart';

/// **What a music player is expected to do** (field reports 2026-09-25,
/// from a playlist played in the car).
///
/// Two habits every music player shares, and this one did not: a song
/// chosen or skipped to starts from the top, and "previous" first returns
/// to the start of the song. Resuming is kept where it earns its place —
/// long listening, and a session coming back after the app was closed.
PlaylistItem _item(String id, {Duration? duration}) => PlaylistItem(
  canonicalUrl: 'https://x/$id',
  title: id,
  serverFilename: '$id.mp3',
  isAudio: true,
  duration: duration,
);

void main() {
  late FakePlayerPort player;
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;
  late MTAudioHandler handler;

  const heard = Duration(seconds: 90);

  MTAudioHandler build() {
    player = FakePlayerPort();
    return MTAudioHandler(
      player: player,
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint(
          buildUrl: (name) => 'https://srv/download/$name',
          headers: const {},
        ),
        fileExists: (_) => false,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
      pausedAutoStop: const Duration(hours: 1),
    );
  }

  setUp(() async {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
    await PlaybackPositionStore(
      store: store,
      mutex: mutex,
    ).save('https://x/a', heard);
    handler = build();
  });

  tearDown(() => handler.dispose());

  group('where a song starts', () {
    test('a song, its length learned on loading, starts from the top even '
        'with a saved position', () async {
      player.duration = const Duration(minutes: 4);
      await handler.playItems([_item('a'), _item('b')]);

      expect(handler.currentItem?.canonicalUrl, 'https://x/a');
      expect(player.position, Duration.zero);
    });

    test('a song whose length is known ahead is never even loaded at the '
        'saved point', () async {
      await handler.playItems([
        _item('a', duration: const Duration(minutes: 4)),
      ]);

      expect(player.position, Duration.zero);
      expect(player.calls, isNot(contains('seek(0:00:00.000000)')));
    });

    test('something long — a lecture, an episode — still picks up where it '
        'was left', () async {
      player.duration = const Duration(minutes: 40);
      await handler.playItems([_item('a')]);

      expect(player.position, heard);
    });

    test('reopening the app continues the song exactly where it was: a '
        'session coming back is not a song being chosen', () async {
      await AudioStateStore(store: store, mutex: mutex).write(
        AudioSessionSnapshot(
          items: [_item('a'), _item('b')],
          index: 0,
          position: heard,
        ),
      );
      player.duration = const Duration(minutes: 4);

      await handler.restoreSession();

      expect(player.position, heard);
    });
  });

  group('"previous", as the car expects it', () {
    test(
      'past three seconds, one press returns to the start of the song',
      () async {
        player.duration = const Duration(minutes: 4);
        await handler.playItems([_item('a'), _item('b')], startIndex: 1);
        player.position = const Duration(seconds: 40);

        await handler.skipToPrevious();

        expect(handler.currentItem?.canonicalUrl, 'https://x/b');
        expect(player.position, Duration.zero);
      },
    );

    test('a second press, straight after, goes to the song before', () async {
      player.duration = const Duration(minutes: 4);
      await handler.playItems([_item('a'), _item('b')], startIndex: 1);
      player.position = const Duration(seconds: 40);

      await handler.skipToPrevious();
      await handler.skipToPrevious();

      expect(handler.currentItem?.canonicalUrl, 'https://x/a');
    });
  });
}
