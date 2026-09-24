import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'fake_player_port.dart';

/// **The guards for the phone-call defect, measured on a real device
/// 2026-09-19** (Galaxy S22 Ultra, Android 16, Super 2.0.2).
///
/// A call paused playback; `androidStopForegroundOnPause: true` dropped the
/// foreground service and the wake lock with it; when the call ended
/// Android refused to start the service again from the background
/// (`ForegroundServiceStartNotAllowedException`); the unprotected process
/// was frozen, the next item died on `SocketTimeoutException`, and **the
/// skip path then stopped the whole session** — a minute of silence for a
/// hiccup that had already passed.
///
/// The service half of the fix lives in each app's `main.dart` and cannot
/// be asserted without a device. **This file guards the half that can be:**
/// a dropped stream is waited for, a broken file is still skipped, and a
/// paused session gives its wake lock back instead of holding it forever.
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
  late MTAudioHandler handler;
  late Set<String> existingFiles;

  String streamOf(String id) => 'https://srv/download/$id.mp3';

  MTAudioHandler build({
    List<Duration> backoff = const [Duration.zero, Duration.zero],
    Duration pausedAutoStop = const Duration(hours: 1),
  }) {
    player = FakePlayerPort();
    return MTAudioHandler(
      player: player,
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint(
          buildUrl: (name) => 'https://srv/download/$name',
          headers: const {'Authorization': 'Basic k'},
        ),
        fileExists: existingFiles.contains,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
      networkRetryBackoff: backoff,
      pausedAutoStop: pausedAutoStop,
    );
  }

  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
    existingFiles = {};
  });

  tearDown(() => handler.dispose());

  group('a dropped stream is waited for, not skipped', () {
    test('an item that fails once is loaded again, and nothing is '
        'skipped', () async {
      handler = build();
      player.failingTimes[streamOf('a')] = 1;

      await handler.playItems([_item('a'), _item('b')]);

      // On the old code the single failure skipped to 'b' and the listener
      // never heard the item it had chosen.
      expect(player.loaded.map((s) => s.uri.toString()), [
        streamOf('a'),
      ], reason: 'the same item comes back after the network does');
      expect(handler.currentItem?.canonicalUrl, 'https://x/a');
    });

    test('it survives more than one drop, up to the backoff length', () async {
      handler = build(
        backoff: const [Duration.zero, Duration.zero, Duration.zero],
      );
      player.failingTimes[streamOf('a')] = 3;

      await handler.playItems([_item('a'), _item('b')]);

      expect(handler.currentItem?.canonicalUrl, 'https://x/a');
      expect(player.loaded.single.uri.toString(), streamOf('a'));
    });

    test('a source that fails every time is given up on and the queue '
        'moves', () async {
      handler = build();
      player.failing.add(streamOf('a'));

      await handler.playItems([_item('a'), _item('b')]);

      expect(player.loaded.map((s) => s.uri.toString()), [
        streamOf('b'),
      ], reason: 'the retries are bounded; a dead source must not stall');
    });

    test('the retry budget is per item, so a later drop is waited for '
        'too', () async {
      handler = build();
      player.failingTimes[streamOf('a')] = 1;
      player.failingTimes[streamOf('b')] = 1;

      await handler.playItems([_item('a'), _item('b')]);
      await handler.skipToNext();

      expect(player.loaded.map((s) => s.uri.toString()), [
        streamOf('a'),
        streamOf('b'),
      ]);
      expect(handler.currentItem?.canonicalUrl, 'https://x/b');
    });

    test('a broken local file is still skipped at once', () async {
      handler = build();
      existingFiles.add('/sd/a.mp3');
      player.failing.add(Uri.file('/sd/a.mp3').toString());

      await handler.playItems([_item('a', localPath: '/sd/a.mp3'), _item('b')]);

      // Waiting for a file that will not open is waiting forever: only a
      // stream is worth a retry.
      expect(player.loaded.single.uri.toString(), streamOf('b'));
    });
  });

  group('a paused session gives the wake lock back', () {
    test('it stops itself after pausedAutoStop', () async {
      handler = build(pausedAutoStop: const Duration(milliseconds: 20));
      await handler.playItems([_item('a'), _item('b')]);

      await handler.pause();
      await pumpEventQueue();
      expect(handler.currentItem, isNotNull, reason: 'not yet');

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(handler.currentItem, isNull);
      expect(handler.queue.value, isEmpty);
      expect(handler.mediaItem.value, isNull, reason: 'no ghost mini player');
      expect(player.calls, contains('stop'));
    });

    test('resuming cancels it', () async {
      handler = build(pausedAutoStop: const Duration(milliseconds: 40));
      await handler.playItems([_item('a')]);

      await handler.pause();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await handler.play();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        handler.currentItem?.canonicalUrl,
        'https://x/a',
        reason: 'the countdown belongs to the pause it started in',
      );
    });

    test('a long pause does not restart the countdown on every '
        'broadcast', () async {
      handler = build(pausedAutoStop: const Duration(milliseconds: 40));
      await handler.playItems([_item('a')]);

      await handler.pause();
      await pumpEventQueue();
      // Broadcasts keep arriving while paused (position ticks, the queue
      // sheet, the notification). A timer restarted by any of them would
      // never fire at all.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 12));
        await handler.setSpeed(1);
      }

      expect(handler.currentItem, isNull);
    });

    test('play after the auto-stop brings the WHOLE list back, not the last '
        'clip alone (field report 2026-09-25: it played on its own and next '
        'did nothing)', () async {
      handler = build(pausedAutoStop: const Duration(milliseconds: 20));
      await handler.playItems([_item('a'), _item('b')]);
      await handler.pause();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(handler.currentItem, isNull, reason: 'auto-stopped');

      // The car, or the earphones.
      await handler.play();

      expect(handler.items, hasLength(2));
      expect(handler.currentItem?.canonicalUrl, 'https://x/a');
      expect(player.playing, isTrue);
      await handler.skipToNext();
      expect(handler.currentItem?.canonicalUrl, 'https://x/b');
    });

    test('a session closed by hand stays closed: play then plays nothing, '
        'not the clip the player still holds', () async {
      handler = build();
      await handler.playItems([_item('a'), _item('b')]);
      await handler.stop();
      player.calls.clear();

      await handler.play();

      expect(player.calls, isNot(contains('play')));
      expect(handler.currentItem, isNull);
    });

    test('stopping by hand cancels the timer rather than leaving it to '
        'fire into a dead session', () async {
      handler = build(pausedAutoStop: const Duration(milliseconds: 20));
      await handler.playItems([_item('a')]);
      await handler.pause();
      await pumpEventQueue();
      await handler.stop();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(handler.currentItem, isNull);
      expect(handler.mediaItem.value, isNull);
    });
  });
}
