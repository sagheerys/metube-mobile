import 'package:mt_core/mt_core.dart';

/// أبعاد مقطع عُرفت بعد تشغيله: المدة والنسبة.
class MediaShape {
  const MediaShape({required this.duration, required this.aspectRatio});

  final Duration duration;
  final double aspectRatio;

  bool get isVertical => aspectRatio > 0 && aspectRatio < 1;

  /// عمودي و≤٣ دقائق ⇒ يدخل مسار القِصار (م-35).
  bool get isShortForm =>
      isVertical && duration > Duration.zero &&
      duration <= const Duration(minutes: 3);
}

/// فهرس أبعاد المقاطع: canonicalUrl → [MediaShape].
///
/// **لماذا يلزم:** السيرفر لا يعطي المدة ولا النسبة، ومسار القِصار
/// (م-35) ورقاقة «⚡ قِصار» في المكتبة يحتاجانهما قبل التشغيل. تُملأ
/// انتهازياً عند أول تشغيل لكل مقطع فتتراكم المعرفة بلا طلب إضافي.
/// مفتاح التخزين `media_shape_index` (إضافة موثقة على §5.1).
final class MediaShapeIndex extends UrlKeyedIndex<MediaShape> {
  MediaShapeIndex({required super.store, required super.mutex})
      : super(prefsKey: 'media_shape_index');

  @override
  MediaShape? decodeValue(dynamic raw) {
    if (raw is! Map) return null;
    final ms = raw['d'];
    final ratio = raw['r'];
    if (ms is! num || ratio is! num) return null;
    return MediaShape(
      duration: Duration(milliseconds: ms.toInt()),
      aspectRatio: ratio.toDouble(),
    );
  }

  @override
  dynamic encodeValue(MediaShape value) => {
        'd': value.duration.inMilliseconds,
        'r': value.aspectRatio,
      };

  Future<void> remember(
    String canonicalUrl,
    Duration duration,
    double aspectRatio,
  ) async {
    if (canonicalUrl.isEmpty || duration <= Duration.zero) return;
    await put(
      canonicalUrl,
      MediaShape(duration: duration, aspectRatio: aspectRatio),
    );
  }
}
