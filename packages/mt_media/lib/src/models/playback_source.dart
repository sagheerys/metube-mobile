import 'dart:io';

import 'package:mt_core/mt_core.dart';

import 'playlist_item.dart';

/// من أين يُشغَّل العنصر فعلياً.
enum PlaybackOrigin { local, stream }

/// مصدر تشغيل جاهز للمشغل: رابط + ترويسات (البث يحتاج Authorization).
class PlaybackSource {
  const PlaybackSource({
    required this.origin,
    required this.uri,
    this.headers = const {},
  });

  final PlaybackOrigin origin;
  final Uri uri;
  final Map<String, String> headers;

  bool get isLocal => origin == PlaybackOrigin.local;

  @override
  String toString() => 'PlaybackSource(${origin.name}, $uri)';
}

/// كل ما يحتاجه التشغيل من السيرفر: بناء رابط الملف وترويسات البث.
/// واجهة ضيقة عمداً — المشغل لا يعرف بقية عقد السيرفر ولا حزمة الشبكة.
class ServerStreamEndpoint {
  const ServerStreamEndpoint({required this.buildUrl, required this.headers});

  /// قد يرمي [UnsafeFilenameException] لاسم ملف خبيث (القاعدة 9).
  final String Function(String serverFilename) buildUrl;
  final Map<String, String> headers;

  factory ServerStreamEndpoint.fromApi(MeTubeApi api) => ServerStreamEndpoint(
        buildUrl: api.downloadUrl,
        headers: api.streamingHeaders,
      );

  /// لا سيرفر مُعد ⇒ المحلي فقط.
  static ServerStreamEndpoint get none => ServerStreamEndpoint(
        buildUrl: (_) => throw const UnsafeFilenameException(),
        headers: const {},
      );
}

/// **القاعدة الذهبية (م-19):** النسخة المحلية إن وُجدت على القرص فعلاً،
/// وإلا البث من السيرفر بترويسات المصادقة. الموضع مشترك بين الحالتين
/// لأن مفتاحه [PlaylistItem.canonicalUrl] لا المسار.
///
/// وجود المسار في الفهرس **لا يكفي** — الملف قد يكون حُذف من خارج
/// التطبيق؛ لذلك يُفحص القرص قبل تفضيله (يُحقن الفاحص للاختبار).
class PlaybackSourceResolver {
  PlaybackSourceResolver({
    required this.endpoint,
    bool Function(String path)? fileExists,
  }) : _fileExists = fileExists ?? _defaultExists;

  final ServerStreamEndpoint endpoint;
  final bool Function(String path) _fileExists;

  static bool _defaultExists(String path) => File(path).existsSync();

  /// null ⇒ لا مصدر صالح (لا ملف محلي ولا اسم ملف صالح على السيرفر).
  PlaybackSource? resolve(PlaylistItem item) {
    final local = item.localPath;
    if (local != null && local.isNotEmpty && _fileExists(local)) {
      return PlaybackSource(origin: PlaybackOrigin.local, uri: Uri.file(local));
    }
    final filename = item.serverFilename;
    if (filename == null || filename.isEmpty) return null;
    try {
      return PlaybackSource(
        origin: PlaybackOrigin.stream,
        uri: Uri.parse(endpoint.buildUrl(filename)),
        headers: endpoint.headers,
      );
    } on UnsafeFilenameException {
      return null;
    }
  }
}
