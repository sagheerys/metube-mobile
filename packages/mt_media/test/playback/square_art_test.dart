import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'fake_player_port.dart';

/// **The notification's square cover (2026-10-10)**: a YouTube song showed
/// as a strip in the notification and on the lock screen. The app makes a
/// square cover; the handler shows it once ready.
void main() {
  late MTAudioHandler handler;

  setUp(() {
    final store = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    handler = MTAudioHandler(
      player: FakePlayerPort(),
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
    );
  });
  tearDown(() => handler.dispose());

  PlaylistItem song(String id) => PlaylistItem(
    canonicalUrl: 'https://www.youtube.com/watch?v=$id',
    title: id,
    artworkUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
    serverFilename: '$id.m4a',
    isAudio: true,
  );

  test('the square cover replaces the thumbnail once ready', () async {
    final made = <String>[];
    handler.squareArt = (item) async {
      made.add(item.title);
      return Uri.file('/cache/square_art/${item.title}.png');
    };
    await handler.playItems([song('aaaaaaaaaaa')]);
    await pumpEventQueue();
    expect(
      handler.mediaItem.value!.artUri,
      Uri.file('/cache/square_art/aaaaaaaaaaa.png'),
    );

    // Played again: made once, shown straight away.
    await handler.playItems([song('aaaaaaaaaaa')]);
    expect(
      handler.mediaItem.value!.artUri,
      Uri.file('/cache/square_art/aaaaaaaaaaa.png'),
    );
    expect(made, ['aaaaaaaaaaa']);
  });

  test('a cover that arrives late does not land on the next song', () async {
    final slow = Completer<Uri?>();
    handler.squareArt = (item) =>
        item.title == 'aaaaaaaaaaa' ? slow.future : Future.value(null);
    await handler.playItems([song('aaaaaaaaaaa'), song('bbbbbbbbbbb')]);
    await handler.skipToNext();
    slow.complete(Uri.file('/cache/square_art/a.png'));
    await pumpEventQueue();
    expect(handler.mediaItem.value!.id, contains('bbbbbbbbbbb'));
    expect(
      handler.mediaItem.value!.artUri.toString(),
      contains('bbbbbbbbbbb/hqdefault.jpg'),
    );
  });

  test('without a maker, or when it fails, the thumbnail stays', () async {
    handler.squareArt = (_) async => throw StateError('no network');
    await handler.playItems([song('ccccccccccc')]);
    await pumpEventQueue();
    expect(
      handler.mediaItem.value!.artUri.toString(),
      contains('hqdefault.jpg'),
    );
  });
}
