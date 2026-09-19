import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../models/playback_source.dart';
import 'media_player_port.dart';

/// A [MediaPlayerPort] implementation over `just_audio`. **The only place**
/// that knows the package, which keeps the player logic testable without a
/// platform.
class JustAudioPort implements MediaPlayerPort {
  JustAudioPort({AudioPlayer? player})
    : _player = player ?? AudioPlayer(audioLoadConfiguration: _loadConfig) {
    _errors = StreamController<Object>.broadcast();
    _eventSub = _player.playbackEventStream.listen(
      (_) => _events.add(null),
      onError: (Object error, StackTrace _) {
        // The event-channel copy of a failure [setSource] already threw.
        if (_swallowNextError) {
          _swallowNextError = false;
          return;
        }
        _errors.add(error);
      },
    );
  }

  /// **Buffering tuned for a home server on a weak link** (field report
  /// 2026-09-19: "with a slow connection it cuts out; with a good one it is
  /// seamless").
  ///
  /// Two things beat the defaults here, and neither is "buffer more for its
  /// own sake":
  ///
  /// - **`prioritizeTimeOverSizeThresholds`**. ExoPlayer honours a byte
  ///   ceiling as well as a time target, and the byte ceiling is the one
  ///   that bites first on anything but a low-bitrate file: the player
  ///   stops filling well short of the 50 seconds it was asked for, and
  ///   then a ten-second drop empties it. With time given priority, the
  ///   seconds asked for are the seconds held.
  /// - **Two minutes rather than fifty seconds.** This is audio: two
  ///   minutes at 128 kbps is under 2 MB, a trivial amount of memory to
  ///   trade for surviving a lift, a tunnel or a Wi-Fi handover — the
  ///   gaps a phone actually meets. Video keeps its own defaults, since
  ///   the same two minutes there would be hundreds of megabytes.
  ///
  /// `bufferForPlaybackAfterRebufferDuration` is raised with them: resuming
  /// after a stall on five seconds of audio invites the next stall
  /// immediately, and the thrash is what a listener notices, not the wait.
  ///
  /// **The byte ceiling is kept** (`prioritizeTimeOverSizeThresholds`
  /// stays off). ExoPlayer's default ceiling is per selected track, and
  /// for an audio track it is about 13 MB — ten minutes at 128 kbps, so
  /// two minutes are held comfortably under it. What the ceiling guards
  /// against is the other case this player meets: **a video file played
  /// as audio** (the player screen hands its clips to this handler), whose
  /// video track is buffered too. Two minutes of a 4K clip is several
  /// hundred megabytes of heap, and the ceiling is what stops it there.
  static const _loadConfig = AudioLoadConfiguration(
    androidLoadControl: AndroidLoadControl(
      minBufferDuration: Duration(minutes: 2),
      maxBufferDuration: Duration(minutes: 2),
      bufferForPlaybackAfterRebufferDuration: Duration(seconds: 10),
    ),
  );

  final AudioPlayer _player;
  final StreamController<void> _events = StreamController<void>.broadcast();
  late final StreamController<Object> _errors;
  StreamSubscription<PlaybackEvent>? _eventSub;

  /// **A load failure reaches Dart twice**, and the contract of
  /// [MediaPlayerPort.errors] is once. just_audio's platform side reports
  /// it to the pending `setAudioSource` call **and** to the event channel
  /// (`AudioPlayer.java`, `sendError`: `prepareResult.error(...)` then
  /// `eventChannel.error(...)`, in that order). The handler counted both:
  /// its three network retries collapsed to one, and the second arrival
  /// could land after the queue had moved on and skip the next item too.
  ///
  /// The two messages are queued together on the platform side, so the
  /// event copy always follows the thrown one and always precedes the
  /// result of any later load. One flag, set on the throw and cleared by
  /// the copy, is therefore exact — not a timing guess.
  bool _swallowNextError = false;

  @override
  Future<void> setSource(
    PlaybackSource source, {
    Duration initialPosition = Duration.zero,
  }) async {
    try {
      await _player.setAudioSource(
        AudioSource.uri(source.uri, headers: source.headers),
        initialPosition: initialPosition,
      );
    } on PlayerInterruptedException {
      // Cut short by a newer load or a dispose, on the Dart side: the
      // platform sends nothing for it, so there is nothing to swallow.
      rethrow;
    } on Object {
      _swallowNextError = true;
      rethrow;
    }
  }

  /// **just_audio's `play()` future does not complete until playback
  /// stops**
  /// — the package's own words: "completes when playback ends or is
  /// stopped". Awaiting it means awaiting the whole clip (field report
  /// 2026-09-03):
  ///
  /// "continue as audio" hung the video screen so it would not close
  /// however
  /// long you waited, **and then** the deferred `pop` ran when the audio
  /// was
  /// stopped, by which time the user had left the screen another way, so it
  /// popped the shell itself: **a black screen**.
  ///
  /// The contract of [MediaPlayerPort.play] is "issue the play command",
  /// not
  /// "play to the end". Errors are forwarded to the error stream so the
  /// handler skips the item.
  @override
  Future<void> play() async {
    unawaited(
      _player.play().catchError((Object error) {
        if (!_errors.isClosed) _errors.add(error);
      }),
    );
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Duration get position => _player.position;

  @override
  Duration get bufferedPosition => _player.bufferedPosition;

  @override
  Duration? get duration => _player.duration;

  @override
  double get speed => _player.speed;

  @override
  bool get playing => _player.playing;

  @override
  MediaPlaybackState get state => _map(_player.processingState);

  @override
  Stream<void> get events => _events.stream;

  @override
  Stream<MediaPlaybackState> get stateStream =>
      _player.processingStateStream.map(_map);

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> dispose() async {
    await _eventSub?.cancel();
    await _events.close();
    await _errors.close();
    await _player.dispose();
  }

  static MediaPlaybackState _map(ProcessingState state) => switch (state) {
    ProcessingState.idle => MediaPlaybackState.idle,
    ProcessingState.loading => MediaPlaybackState.loading,
    ProcessingState.buffering => MediaPlaybackState.buffering,
    ProcessingState.ready => MediaPlaybackState.ready,
    ProcessingState.completed => MediaPlaybackState.completed,
  };
}
