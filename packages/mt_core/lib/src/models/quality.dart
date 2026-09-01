import '../urls/platform_detector.dart';

/// جودات MeTube المعتمدة (`05-DATA-SCHEMA.md` §2.2).
enum Quality {
  best('best'),
  q1080('1080'),
  q720('720'),
  q480('480'),
  audio('audio');

  const Quality(this.wire);

  /// القيمة كما تُرسل في `POST /add`.
  final String wire;

  bool get isNumeric =>
      this == Quality.q1080 || this == Quality.q720 || this == Quality.q480;

  /// **قاعدة المنصة الإلزامية:** الجودات الرقمية لـ YouTube فقط — أي منصة
  /// أخرى تُجبر على `best`. `audio` و`best` للجميع. (قيد من yt-dlp.)
  Quality applyRule(String url) {
    if (!isNumeric) return this;
    return MediaPlatform.detect(url).isYouTube ? this : Quality.best;
  }

  /// قراءة متسامحة لقيمة مخزنة/واردة؛ غير المعروف ⇒ `best`.
  static Quality fromWire(String? value) {
    final v = value?.trim().toLowerCase();
    for (final q in Quality.values) {
      if (q.wire == v) return q;
    }
    return Quality.best;
  }
}
