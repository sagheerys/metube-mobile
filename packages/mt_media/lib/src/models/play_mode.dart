/// أوضاع التشغيل (م-20): تلقائي للتالي / تكرار واحد / تكرار الكل /
/// إيقاف عند النهاية. القيمة المخزنة نصية تحت `player_play_mode`.
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

  /// الدورة على الزر الواحد في المشغلات.
  PlayMode get next => values[(index + 1) % values.length];
}

/// سرعات التشغيل المعروضة (م-20) — المحفوظة تُقصّ إلى هذا المدى.
class PlaybackSpeeds {
  const PlaybackSpeeds._();

  static const List<double> options = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  static const double normal = 1.0;
  static const double min = 0.25;
  static const double max = 3.0;

  static double clamp(double value) =>
      value.isNaN ? normal : value.clamp(min, max);
}
