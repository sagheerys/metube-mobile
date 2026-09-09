import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'fake_player_port.dart';

PlaylistItem _item(String id, {String? localPath}) => PlaylistItem(
  canonicalUrl: 'https://x/$id',
  title: id,
  serverFilename: '$id.mp3',
  localPath: localPath,
  isAudio: true,
);

void main() {
  late FakePlayerPort player;
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;
  late PlaybackPositionStore positions;
  late PlaybackPrefs prefs;
  late AudioStateStore states;
  late MTAudioHandler handler;
  late Set<String> existingFiles;

  MTAudioHandler build() {
    player = FakePlayerPort();
    positions = PlaybackPositionStore(store: store, mutex: mutex);
    prefs = PlaybackPrefs(store: store, mutex: mutex);
    states = AudioStateStore(store: store, mutex: mutex);
    return MTAudioHandler(
      player: player,
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint(
          buildUrl: (name) => 'https://srv/download/$name',
          headers: const {'Authorization': 'Basic k'},
        ),
        fileExists: existingFiles.contains,
      ),
      positions: positions,
      prefs: prefs,
      stateStore: states,
      saveInterval: const Duration(
        hours: 1,
      ), // the periodic save is triggered by hand here
    );
  }

  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
    existingFiles = {};
    handler = build();
  });

  tearDown(() => handler.dispose());

  group('playback and the golden rule', () {
    test('it streams from the server when there is no local copy', () async {
      await handler.playItems([_item('a')]);
      expect(player.loaded.single.origin, PlaybackOrigin.stream);
      expect(player.loaded.single.headers['Authorization'], 'Basic k');
      expect(player.playing, isTrue);
    });

    test('it prefers a local copy that really exists', () async {
      existingFiles.add('/sd/a.mp3');
      await handler.playItems([_item('a', localPath: '/sd/a.mp3')]);
      expect(player.loaded.single.origin, PlaybackOrigin.local);
    });

    test('it resumes from the position saved for that same URL', () async {
      await positions.save('https://x/a', const Duration(seconds: 65));
      await handler.playItems([_item('a')]);
      expect(player.position, const Duration(seconds: 65));
    });

    test('it fills mediaItem and the queue for the notification', () async {
      await handler.playItems([_item('a'), _item('b')]);
      expect(handler.mediaItem.value!.id, 'https://x/a');
      expect(handler.queue.value.length, 2);
      expect(handler.playbackState.value.playing, isTrue);
    });

    test('autoPlay false loads without playing', () async {
      await handler.playItems([_item('a')], autoPlay: false);
      expect(player.playing, isFalse);
      expect(handler.mediaItem.value, isNotNull);
    });
  });

  group('the play modes', () {
    test('automatic: finishing moves to the next', () async {
      await handler.playItems([_item('a'), _item('b')]);
      await handler.onCompleted();
      expect(handler.currentItem!.title, 'b');
      expect(player.loaded.length, 2);
    });

    test('repeat one replays the same clip from the start', () async {
      await prefs.setPlayMode(PlayMode.repeatOne);
      handler = build();
      await handler.playItems([_item('a'), _item('b')]);
      await handler.onCompleted();
      expect(handler.currentItem!.title, 'a');
      expect(player.calls, contains('seek(0:00:00.000000)'));
    });

    test('repeat all wraps round to the head of the list', () async {
      await prefs.setPlayMode(PlayMode.repeatAll);
      handler = build();
      await handler.playItems([_item('a'), _item('b')], startIndex: 1);
      await handler.onCompleted();
      expect(handler.currentItem!.title, 'a');
    });

    test(
      'stop at the end does not advance: it stops with the item still there',
      () async {
        await prefs.setPlayMode(PlayMode.stopAtEnd);
        handler = build();
        await handler.playItems([_item('a'), _item('b')]);
        await handler.onCompleted();
        expect(handler.currentItem!.title, 'a');
        expect(player.playing, isFalse);
        expect(handler.mediaItem.value, isNotNull);
      },
    );

    test('a manual next is not trapped by repeat one', () async {
      await prefs.setPlayMode(PlayMode.repeatOne);
      handler = build();
      await handler.playItems([_item('a'), _item('b')]);
      await handler.skipToNext();
      expect(handler.currentItem!.title, 'b');
    });

    test('the speed is saved and applied', () async {
      await handler.playItems([_item('a')]);
      await handler.setSpeed(1.5);
      expect(player.speed, 1.5);
      expect(await prefs.speed(), 1.5);
    });
  });

  group('skipping past what is broken', () {
    test('an item with no source is skipped to the next', () async {
      await handler.playItems([
        const PlaylistItem(canonicalUrl: 'https://x/bad', title: 'bad'),
        _item('b'),
      ]);
      expect(handler.currentItem!.title, 'b');
      expect(player.loaded.single.uri.toString(), contains('b.mp3'));
    });

    test('a source that fails on load is skipped', () async {
      player.failing.add('https://srv/download/a.mp3');
      await handler.playItems([_item('a'), _item('b')]);
      expect(handler.currentItem!.title, 'b');
    });

    test('every item broken means a full stop, not a spin', () async {
      await handler.playItems([
        const PlaylistItem(canonicalUrl: 'https://x/1', title: '1'),
        const PlaylistItem(canonicalUrl: 'https://x/2', title: '2'),
      ]);
      expect(handler.mediaItem.value, isNull);
      expect(handler.queue.value, isEmpty);
      expect(handler.currentItem, isNull);
    });
  });

  group('saving the position and the session', () {
    test('pausing saves the position', () async {
      await handler.playItems([_item('a')]);
      player.position = const Duration(seconds: 40);
      await handler.pause();
      expect(
        await positions.positionOf('https://x/a'),
        const Duration(seconds: 40),
      );
    });

    test("moving to the next saves the previous one's position", () async {
      await handler.playItems([_item('a'), _item('b')]);
      player.position = const Duration(seconds: 33);
      await handler.skipToNext();
      expect(
        await positions.positionOf('https://x/a'),
        const Duration(seconds: 33),
      );
    });

    test('a clip finishing clears its position', () async {
      await handler.playItems([_item('a'), _item('b')]);
      player.position = const Duration(seconds: 50);
      await handler.persist();
      await handler.onCompleted();
      expect(await positions.positionOf('https://x/a'), isNull);
    });

    test(
      'the session is saved and restored, without playing automatically',
      () async {
        await handler.playItems([_item('a'), _item('b')], startIndex: 1);
        player.position = const Duration(seconds: 25);
        await handler.persist();
        await handler.dispose();

        handler = build();
        expect(await handler.restoreSession(), isTrue);
        expect(handler.currentItem!.title, 'b');
        expect(player.position, const Duration(seconds: 25));
        expect(player.playing, isFalse, reason: 'الاستعادة لا تشغّل تلقائياً');
      },
    );

    test('with no saved session, restoring returns false', () async {
      expect(await handler.restoreSession(), isFalse);
    });
  });

  group('the trap: no ghost mini player', () {
    test(
      'stop clears mediaItem, the queue and the saved state together',
      () async {
        await handler.playItems([_item('a'), _item('b')]);
        await handler.persist();
        expect(await states.read(), isNotNull);

        await handler.stop();

        expect(handler.mediaItem.value, isNull, reason: 'شرط إخفاء المصغر');
        expect(handler.queue.value, isEmpty);
        expect(handler.currentItem, isNull);
        expect(handler.playbackState.value.playing, isFalse);
        expect(
          handler.playbackState.value.processingState,
          AudioProcessingState.idle,
        );
        expect(
          await states.read(),
          isNull,
          reason: 'وإلا عاد الشبح بعد إعادة التشغيل',
        );
      },
    );

    test('after stop, restoring revives nothing', () async {
      await handler.playItems([_item('a')]);
      await handler.persist();
      await handler.stop();
      await handler.dispose();

      handler = build();
      expect(await handler.restoreSession(), isFalse);
      expect(handler.mediaItem.value, isNull);
    });

    test('stop saves the resume position before it cleans up', () async {
      await handler.playItems([_item('a')]);
      player.position = const Duration(seconds: 88);
      await handler.stop();
      expect(
        await positions.positionOf('https://x/a'),
        const Duration(seconds: 88),
      );
    });
  });

  group('shuffle and the queue', () {
    test(
      'toggling shuffle republishes the queue and saves the preference',
      () async {
        await handler.playItems([_item('a'), _item('b'), _item('c')]);
        await handler.setShuffle(true);
        expect(handler.shuffleEnabled, isTrue);
        expect(await prefs.shuffle(), isTrue);
        expect(handler.queue.value.length, 3);
        expect(handler.queue.value.first.id, handler.currentItem!.canonicalUrl);
      },
    );

    test('tapping an item in the sheet jumps to it', () async {
      await handler.playItems([_item('a'), _item('b'), _item('c')]);
      await handler.skipToQueueItem(2);
      expect(handler.currentItem!.title, 'c');
    });
  });
}
