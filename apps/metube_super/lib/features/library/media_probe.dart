import 'package:flutter/services.dart';

/// طلب سبر واحد: مفتاح العنصر + مصدره (ملف محلي أو رابط بثّ).
class ProbeRequest {
  const ProbeRequest({required this.key, this.path, this.url});

  final String key;
  final String? path;
  final String? url;

  Map<String, Object?> toMap() => {'key': key, 'path': path, 'url': url};
}

/// نتيجة سبر — أي حقل قد يغيب (ترميز غير مدعوم أو سيرفر غير متاح).
class ProbedMedia {
  const ProbedMedia({
    required this.key,
    this.duration,
    this.width,
    this.height,
    this.thumbPath,
    this.error,
  });

  final String key;
  final Duration? duration;
  final int? width;
  final int? height;

  /// مسار المصغرة في كاش التطبيق (لا رابط شبكة).
  final String? thumbPath;

  /// سبب الإخفاق كما رفعته المنصة — للسجل التشخيصي لا للعرض (م-47).
  final String? error;

  double? get aspectRatio =>
      (width == null || height == null || height! <= 0)
          ? null
          : width! / height!;

  bool get isEmpty => duration == null && width == null && thumbPath == null;

  static ProbedMedia? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key']?.toString();
    if (key == null || key.isEmpty) return null;
    final ms = (raw['durationMs'] as num?)?.toInt();
    final thumb = raw['thumb']?.toString();
    final error = raw['error']?.toString();
    return ProbedMedia(
      key: key,
      error: (error == null || error.isEmpty) ? null : error,
      duration: ms == null || ms <= 0 ? null : Duration(milliseconds: ms),
      width: (raw['width'] as num?)?.toInt(),
      height: (raw['height'] as num?)?.toInt(),
      thumbPath: (thumb == null || thumb.isEmpty) ? null : thumb,
    );
  }
}

/// م-18 + م-35 لـ Super — راجع `MediaProbe.kt` لسبب وجود القناة الأصلية.
class MediaProbe {
  const MediaProbe([this.channel = _defaultChannel]);

  static const _defaultChannel =
      MethodChannel('com.yasir.metubesuper/permissions');
  final MethodChannel channel;

  Future<List<ProbedMedia>> probe(
    List<ProbeRequest> requests, {
    Map<String, String> headers = const {},
  }) async {
    if (requests.isEmpty) return const [];
    try {
      final raw = await channel.invokeMethod<List<Object?>>('probeMedia', {
        'items': [for (final request in requests) request.toMap()],
        'headers': headers,
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
