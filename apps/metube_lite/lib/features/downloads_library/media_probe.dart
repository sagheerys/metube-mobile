import 'package:flutter/services.dart';

/// نتيجة سبر ملف واحد — أي حقل قد يغيب (ملف تالف أو ترميز غير مدعوم).
class ProbedMedia {
  const ProbedMedia({
    required this.path,
    this.duration,
    this.width,
    this.height,
    this.thumbPath,
  });

  final String path;
  final Duration? duration;
  final int? width;
  final int? height;

  /// مسار المصغرة المولّدة في كاش التطبيق (لا رابط شبكة).
  final String? thumbPath;

  double? get aspectRatio =>
      (width == null || height == null || height! <= 0)
          ? null
          : width! / height!;

  bool get isEmpty => duration == null && width == null && thumbPath == null;

  static ProbedMedia? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path']?.toString();
    if (path == null || path.isEmpty) return null;
    final ms = (raw['durationMs'] as num?)?.toInt();
    return ProbedMedia(
      path: path,
      duration: ms == null || ms <= 0 ? null : Duration(milliseconds: ms),
      width: (raw['width'] as num?)?.toInt(),
      height: (raw['height'] as num?)?.toInt(),
      thumbPath: (raw['thumb'] as String?)?.trim().isEmpty ?? true
          ? null
          : raw['thumb'] as String,
    );
  }
}

/// م-18 + م-35: سبر الملفات المحلية عبر القناة الأصلية
/// (`MediaMetadataRetriever`). راجع `MediaProbe.kt` لسبب وجودها.
class MediaProbe {
  const MediaProbe([this.channel = _defaultChannel]);

  static const _defaultChannel = MethodChannel('metube_lite/media');
  final MethodChannel channel;

  Future<List<ProbedMedia>> probe(List<String> paths) async {
    if (paths.isEmpty) return const [];
    try {
      final raw =
          await channel.invokeMethod<List<Object?>>('probeMedia', {
        'paths': paths,
      });
      return [
        for (final entry in raw ?? const []) ?ProbedMedia.fromMap(entry),
      ];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}
