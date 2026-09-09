import 'dart:async';

import 'package:mt_media/mt_media.dart';

/// A fully controllable fake player, so [MTAudioHandler]'s logic can be
/// tested with no platform channels: the modes, skipping a broken item,
/// saving the position, and "no ghost player".
class FakePlayerPort implements MediaPlayerPort {
  final _events = StreamController<void>.broadcast();
  final _states = StreamController<MediaPlaybackState>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  /// The sources it was asked to play, in order, for checking the golden
  /// rule.
  final List<PlaybackSource> loaded = [];
  final List<String> calls = [];

  /// URLs that fail on load (a broken source).
  final Set<String> failing = {};

  @override
  Duration position = Duration.zero;
  @override
  Duration bufferedPosition = Duration.zero;
  @override
  Duration? duration;
  @override
  double speed = 1;
  @override
  bool playing = false;
  @override
  MediaPlaybackState state = MediaPlaybackState.idle;

  bool disposed = false;

  @override
  Future<void> setSource(
    PlaybackSource source, {
    Duration initialPosition = Duration.zero,
  }) async {
    if (failing.contains(source.uri.toString())) {
      throw StateError('مصدر معطوب: ${source.uri}');
    }
    loaded.add(source);
    calls.add('setSource(${source.uri})');
    position = initialPosition;
    state = MediaPlaybackState.ready;
  }

  @override
  Future<void> play() async {
    playing = true;
    calls.add('play');
    _events.add(null);
  }

  @override
  Future<void> pause() async {
    playing = false;
    calls.add('pause');
    _events.add(null);
  }

  @override
  Future<void> stop() async {
    playing = false;
    state = MediaPlaybackState.idle;
    calls.add('stop');
  }

  @override
  Future<void> seek(Duration to) async {
    position = to;
    calls.add('seek($to)');
  }

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
    calls.add('setSpeed($value)');
  }

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
    disposed = true;
    await _events.close();
    await _states.close();
    await _errors.close();
    await _positions.close();
  }

  /// Simulates a clip ending naturally.
  void emitCompleted() {
    state = MediaPlaybackState.completed;
    _states.add(MediaPlaybackState.completed);
  }

  void emitError(Object error) => _errors.add(error);
}
