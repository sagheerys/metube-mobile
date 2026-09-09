import '../models/playback_source.dart';

/// The player state as our logic sees it, independent of the playback
/// package.
enum MediaPlaybackState { idle, loading, buffering, ready, completed }

/// The port through which [MTAudioHandler] talks to any real player.
///
/// It exists deliberately: the queue logic, the modes, position saving and
/// "no ghost player" are all tested without platform channels (TRD §3.2),
/// and the playback package stays a detail replaceable in one place.
abstract interface class MediaPlayerPort {
  Future<void> setSource(PlaybackSource source, {Duration initialPosition});

  /// **Its contract is "issue the play command", not "play to the end"**:
  /// its future completes when the command is accepted. `just_audio` does
  /// the opposite, completing on stop, and wrapping it is what preserves
  /// this contract. Breaking it hung the video screen and popped the shell
  /// later (field report 2026-09-03).
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);

  Duration get position;
  Duration get bufferedPosition;
  Duration? get duration;
  double get speed;
  bool get playing;
  MediaPlaybackState get state;

  /// Any change that requires the notification state to be rebroadcast.
  Stream<void> get events;
  Stream<MediaPlaybackState> get stateStream;
  Stream<Duration> get positionStream;

  /// Playback errors, a broken source or a dropped network, which trigger
  /// an automatic skip.
  Stream<Object> get errors;

  Future<void> dispose();
}
