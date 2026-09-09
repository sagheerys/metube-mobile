import '../urls/platform_detector.dart';

/// The MeTube qualities in use (`05-DATA-SCHEMA.md` §2.2).
enum Quality {
  best('best'),
  q1080('1080'),
  q720('720'),
  q480('480'),
  audio('audio');

  const Quality(this.wire);

  /// The value as sent in `POST /add`.
  final String wire;

  bool get isNumeric =>
      this == Quality.q1080 || this == Quality.q720 || this == Quality.q480;

  /// **The mandatory platform rule:** numeric qualities are for YouTube
  /// only; every other platform is forced to `best`. `audio` and `best` are
  /// available everywhere. This is a yt-dlp constraint.
  Quality applyRule(String url) {
    if (!isNumeric) return this;
    return MediaPlatform.detect(url).isYouTube ? this : Quality.best;
  }

  /// Tolerant reading of a stored or incoming value; anything unknown
  /// becomes `best`.
  static Quality fromWire(String? value) {
    final v = value?.trim().toLowerCase();
    for (final q in Quality.values) {
      if (q.wire == v) return q;
    }
    return Quality.best;
  }
}
