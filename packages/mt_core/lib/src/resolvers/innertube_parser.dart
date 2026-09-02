import '../models/playlist_preview.dart';
import '../urls/playlist_detector.dart';

/// تحليل خالص لاستجابة InnerTube (`/youtubei/v1/browse`) — بلا شبكة،
/// فيُختبر بعينات JSON حقيقية.
///
/// **يوتيوب 2026 يستعمل «نماذج العرض» لا «المصيّرات»:** كل عنصر قائمة
/// صار `lockupViewModel` بحقول مسطحة، ولم يعد `playlistVideoRenderer`
/// موجوداً — وهذا سبب رجوع القوائم **فارغة**.
abstract final class InnertubeParser {
  /// معرف الفيديو + عنوانه + مدته من `lockupViewModel`.
  static PlaylistPreview? parseBrowse(Object? data, {String? fallbackTitle}) {
    final tracks = <PlaylistTrack>[];
    String? title = fallbackTitle;

    walk(data, (map) {
      final lockup = map['lockupViewModel'];
      if (lockup is Map) {
        final track = _trackOf(lockup);
        if (track != null) tracks.add(track);
      }
      final meta = map['playlistMetadataRenderer'];
      if (meta is Map) {
        title ??= meta['title']?.toString();
      }
      final header = map['pageHeaderViewModel'];
      if (header is Map) {
        title ??= header['title']?['dynamicTextViewModel']?['text']?['content']
            ?.toString();
      }
    });

    if (tracks.isEmpty) return null;
    return PlaylistPreview(
      kind: PlaylistKind.youtube,
      title: title ?? '',
      coverUrl: tracks.first.thumbnail,
      tracks: tracks,
    );
  }

  /// رمز الصفحة التالية — يوتيوب يغلّفه بعمقين مختلفين حسب الشكل.
  static String? continuationToken(Object? data) {
    String? token;
    walk(data, (map) {
      final item = map['continuationItemRenderer'] ?? map['continuationItemViewModel'];
      if (item is! Map) return;
      final direct = item['continuationEndpoint']?['continuationCommand'];
      if (direct is Map && direct['token'] is String) {
        token = direct['token'] as String;
        return;
      }
      final nested = item['continuationCommand']?['innertubeCommand']
          ?['continuationCommand'];
      if (nested is Map && nested['token'] is String) {
        token = nested['token'] as String;
      }
    });
    return token;
  }

  static PlaylistTrack? _trackOf(Map<dynamic, dynamic> lockup) {
    if (lockup['contentType'] != 'LOCKUP_CONTENT_TYPE_VIDEO') return null;
    final id = lockup['contentId']?.toString();
    if (id == null || id.isEmpty) return null;
    final title = lockup['metadata']?['lockupMetadataViewModel']?['title']
            ?['content']
        ?.toString();
    return PlaylistTrack(
      url: 'https://www.youtube.com/watch?v=$id',
      title: title ?? id,
      duration: _durationOf(lockup),
      // غلاف مستقر بدل روابط `sqp=` المؤقتة التي تنتهي صلاحيتها.
      thumbnail: 'https://i.ytimg.com/vi/$id/mqdefault.jpg',
    );
  }

  /// المدة تصل نصاً في شارة المصغّرة («16:09» أو «1:02:33»).
  static Duration? _durationOf(Map<dynamic, dynamic> lockup) {
    String? text;
    walk(lockup['contentImage'], (map) {
      final badge = map['thumbnailBadgeViewModel'];
      if (badge is Map && text == null) text = badge['text']?.toString();
    });
    return parseClock(text);
  }

  /// «mm:ss» أو «h:mm:ss» ⇒ [Duration]، وأي شيء آخر ⇒ null.
  static Duration? parseClock(String? text) {
    if (text == null) return null;
    final parts = text.trim().split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final numbers = [for (final p in parts) int.tryParse(p)];
    if (numbers.any((n) => n == null)) return null;
    return parts.length == 2
        ? Duration(minutes: numbers[0]!, seconds: numbers[1]!)
        : Duration(
            hours: numbers[0]!, minutes: numbers[1]!, seconds: numbers[2]!);
  }

  /// جولة عميقة على JSON — بنية يوتيوب تتغير كثيراً، فالبحث بالمفتاح
  /// أصلب من المسار الثابت.
  static void walk(Object? node, void Function(Map<dynamic, dynamic>) onMap) {
    if (node is Map) {
      onMap(node);
      for (final value in node.values) {
        walk(value, onMap);
      }
    } else if (node is List) {
      for (final value in node) {
        walk(value, onMap);
      }
    }
  }
}
