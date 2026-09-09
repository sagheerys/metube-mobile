import 'dart:async';

import 'package:mt_media/mt_media.dart';

/// A fake player for the interface tests: no platform channels and no real
/// audio.
class FakeMediaPlayer implements MediaPlayerPort {
  final _events = StreamController<void>.broadcast();
  final _states = StreamController<MediaPlaybackState>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  @override
  Duration position = Duration.zero;
  @override
  Duration bufferedPosition = Duration.zero;
  @override
  Duration? duration = const Duration(minutes: 3);
  @override
  double speed = 1;
  @override
  bool playing = false;
  @override
  MediaPlaybackState state = MediaPlaybackState.idle;

  @override
  Future<void> setSource(
    PlaybackSource source, {
    Duration initialPosition = Duration.zero,
  }) async {
    position = initialPosition;
    state = MediaPlaybackState.ready;
  }

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;

  @override
  Future<void> stop() async {
    playing = false;
    state = MediaPlaybackState.idle;
  }

  @override
  Future<void> seek(Duration to) async => position = to;

  @override
  Future<void> setSpeed(double value) async => speed = value;

  @override
  Stream<void> get events => _events.stream;
  @override
  Stream<MediaPlaybackState> get stateStream => _states.stream;
  @override
  Stream<Duration> get positionStream => _positions.stream;
  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> dispose() async {
    await _events.close();
    await _states.close();
    await _errors.close();
    await _positions.close();
  }
}
