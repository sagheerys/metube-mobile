/// Play modes: auto-advance, repeat one, repeat all, stop at the end. The
/// stored value is a string under `player_play_mode`.
enum PlayMode {
  autoNext('auto'),
  repeatOne('repeat_one'),
  repeatAll('repeat_all'),
  stopAtEnd('stop');

  const PlayMode(this.wire);

  final String wire;

  static PlayMode fromWire(String? value) => values.firstWhere(
    (m) => m.wire == value,
    orElse: () => PlayMode.autoNext,
  );

  /// The cycle driven by the single button in the players.
  PlayMode get next => values[(index + 1) % values.length];
}

/// The playback speeds offered; a stored value is clamped to this range.
class PlaybackSpeeds {
  const PlaybackSpeeds._();

  static const List<double> options = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const double normal = 1.0;
  static const double min = 0.25;
  static const double max = 3.0;

  static double clamp(double value) =>
      value.isNaN ? normal : value.clamp(min, max);
}
