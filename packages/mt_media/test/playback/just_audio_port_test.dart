import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mt_media/mt_media.dart';

/// **A load failure reaches Dart twice, and the port reports it once**
/// (pre-release review 2026-09-19).
///
/// just_audio's platform side sends one failure to the pending
/// `setAudioSource` call **and** to the event channel, in that order. The
/// handler above the port counted both, so its three network retries
/// collapsed to one — the headline fix of the day did not do what its
/// changelog said — and the second arrival could land after the queue had
/// moved on and skip the next item as well.
///
/// The player is faked at the just_audio boundary: this is the one place
/// that knows the quirk, and the one place a test of it belongs.
void main() {
  late _FakeJustAudio player;
  late JustAudioPort port;
  late List<Object> reported;

  setUp(() {
    player = _FakeJustAudio();
    port = JustAudioPort(player: player);
    reported = [];
    port.errors.listen(reported.add);
  });

  tearDown(() => player.events.close());

  final source = PlaybackSource(
    uri: Uri.parse('https://srv/download/a.mp3'),
    origin: PlaybackOrigin.stream,
  );

  test('the event-channel copy of a thrown load failure is dropped', () async {
    player.failNextLoad = true;

    await expectLater(port.setSource(source), throwsA(isA<PlayerException>()));
    await pumpEventQueue();

    expect(reported, isEmpty, reason: 'the throw already said it');
  });

  test('a failure during playback is still reported', () async {
    await port.setSource(source);
    player.events.addError(PlayerException(0, 'connection reset'));
    await pumpEventQueue();

    expect(reported, hasLength(1));
  });

  test('an interrupted load swallows nothing: the platform sends '
      'nothing for it', () async {
    player.interruptNextLoad = true;

    await expectLater(
      port.setSource(source),
      throwsA(isA<PlayerInterruptedException>()),
    );
    // The genuine error that follows must not be eaten by a flag left
    // armed for a copy that never comes.
    player.events.addError(PlayerException(0, 'connection reset'));
    await pumpEventQueue();

    expect(reported, hasLength(1));
  });

  test('one flag serves one failure: the next failure is dropped too, '
      'and its copy only', () async {
    player.failNextLoad = true;
    await expectLater(port.setSource(source), throwsA(isA<PlayerException>()));
    await pumpEventQueue();
    player.failNextLoad = true;
    await expectLater(port.setSource(source), throwsA(isA<PlayerException>()));
    await pumpEventQueue();
    player.events.addError(PlayerException(0, 'later, for real'));
    await pumpEventQueue();

    expect(reported, hasLength(1));
  });
}

/// The just_audio boundary, faked: only what the port touches during a
/// load, with the platform's double delivery reproduced in order.
class _FakeJustAudio implements AudioPlayer {
  final events = StreamController<PlaybackEvent>.broadcast();
  bool failNextLoad = false;
  bool interruptNextLoad = false;

  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    if (interruptNextLoad) {
      interruptNextLoad = false;
      throw PlayerInterruptedException('newer load');
    }
    if (failNextLoad) {
      failNextLoad = false;
      final failure = PlayerException(0, 'Source error');
      // As on the platform: the pending call fails first, and the event
      // channel carries the same failure a message later.
      unawaited(Future(() => events.addError(failure)));
      throw failure;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
