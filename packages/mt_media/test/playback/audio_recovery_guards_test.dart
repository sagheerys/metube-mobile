import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'fake_player_port.dart';

/// **Two holes found by the pre-release review of 2026-09-19**, in the
/// paused auto-stop shipped the same day. (The third, a load failure
/// counted twice, lives in the port: see `just_audio_port_test.dart`.)
///
/// 1. The timer armed on a **restored** session nobody had tapped yet, and
///    wiped it — mini player, saved session and all — fifteen minutes
///    after opening the app. No wake lock was held there, so the timer
///    bought nothing.
/// 2. `stop()` broadcast through its own `player.stop()` while the queue
///    was still full, arming a ghost timer that fired into whatever
///    session came next.
void main() {
  late FakePlayerPort player;
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;
  late MTAudioHandler handler;

  MTAudioHandler build({Duration pausedAutoStop = const Duration(hours: 1)}) {
    player = FakePlayerPort();
    return MTAudioHandler(
      player: player,
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint(
          buildUrl: (name) => 'https://srv/download/$name',
          headers: const {'Authorization': 'Basic k'},
        ),
        fileExists: (_) => false,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
      pausedAutoStop: pausedAutoStop,
    );
  }

  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
  });

  tearDown(() => handler.dispose());

  test('a restored session that was never played is left alone', () async {
    handler = build(pausedAutoStop: const Duration(milliseconds: 20));
    // A session saved by an earlier run.
    await AudioStateStore(store: store, mutex: mutex).write(
      AudioSessionSnapshot(
        items: [_item('a'), _item('b')],
        index: 0,
        position: const Duration(seconds: 30),
      ),
    );

    expect(await handler.restoreSession(), isTrue);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(
      handler.currentItem?.canonicalUrl,
      'https://x/a',
      reason: 'nobody paused it; the mini player waits for a tap',
    );
    expect(handler.mediaItem.value, isNotNull);
  });

  test('stopping does not arm a timer for the session that follows', () async {
    handler = build(pausedAutoStop: const Duration(milliseconds: 20));
    await handler.playItems([_item('a')]);
    await handler.pause();
    await pumpEventQueue();
    await handler.stop();

    // A new session that has not started playing yet — a restored one,
    // or the seconds between the tap and the first "playing" broadcast.
    await handler.playItems([_item('b')], autoPlay: false);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(
      handler.currentItem?.canonicalUrl,
      'https://x/b',
      reason: 'the ghost timer from the stop used to fire into it',
    );
  });
}

PlaylistItem _item(String id) => PlaylistItem(
  canonicalUrl: 'https://x/$id',
  title: id,
  serverFilename: '$id.mp3',
  isAudio: true,
);
