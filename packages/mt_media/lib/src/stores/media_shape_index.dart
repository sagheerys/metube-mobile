import 'package:mt_core/mt_core.dart';

/// A clip's dimensions, learned after playing it: the duration and the
/// ratio.
class MediaShape {
  const MediaShape({required this.duration, required this.aspectRatio});

  final Duration duration;
  final double aspectRatio;

  bool get isVertical => aspectRatio > 0 && aspectRatio < 1;

  /// Portrait and three minutes or less enters the shorts path.
  bool get isShortForm =>
      isVertical &&
      duration > Duration.zero &&
      duration <= const Duration(minutes: 3);
}

/// The clip shape index: canonicalUrl to [MediaShape].
///
/// **Why it is needed:** the server gives neither duration nor ratio, and
/// both the shorts path and the "shorts" chip in the library need them
/// before playback. It is filled opportunistically on the first play of
/// each clip, so the knowledge accumulates with no extra request. Storage
/// key: `media_shape_index`, a documented addition to §5.1.
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
