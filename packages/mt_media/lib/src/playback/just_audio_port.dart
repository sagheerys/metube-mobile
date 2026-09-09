import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../models/playback_source.dart';
import 'media_player_port.dart';

/// A [MediaPlayerPort] implementation over `just_audio`. **The only place**
/// that knows the package, which keeps the player logic testable without a
/// platform.
class JustAudioPort implements MediaPlayerPort {
  JustAudioPort({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _errors = StreamController<Object>.broadcast();
    _eventSub = _player.playbackEventStream.listen(
      (_) => _events.add(null),
      onError: (Object error, StackTrace _) => _errors.add(error),
    );
  }

  final AudioPlayer _player;
  final StreamController<void> _events = StreamController<void>.broadcast();
  late final StreamController<Object> _errors;
  StreamSubscription<PlaybackEvent>? _eventSub;

  @override
  Future<void> setSource(
    PlaybackSource source, {
    Duration initialPosition = Duration.zero,
  }) =>
      _player.setAudioSource(
        AudioSource.uri(source.uri, headers: source.headers),
        initialPosition: initialPosition,
      );

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
    unawaited(_player.play().catchError((Object error) {
      if (!_errors.isClosed) _errors.add(error);
    }));
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
