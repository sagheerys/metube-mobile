import 'dart:convert';

import '../models/playlist_preview.dart';
import '../urls/playlist_detector.dart';
import 'http_fetch.dart';
import 'innertube_parser.dart';

/// قوائم YouTube — فشل-آمن: null عند أي خطأ (شاشة الدفعي تعرض رسالة).
///
/// **مكتوب على InnerTube مباشرة لا على `youtube_explode_dart`** (بلاغ
/// المالك 2026-09-02: «القائمة تظهر صفحة فارغة»). أُثبت بالتشغيل الحقيقي
/// أن `yt.playlists.getVideos()` يبثّ **صفر عناصر** لقائمة عدّادها 19 —
/// في 2.5.3 وفي أحدث إصدار 3.1.0 معاً، لأن يوتيوب استبدل
/// `playlistVideoRenderer` بـ`lockupViewModel`. المشروع القديم في
/// `Z:\MTD` يستعمل الحزمة نفسها، أي أن العطل موروث لا مستجد.
///
/// النقطة `browse` مع `browseId: VL<id>` **بلا مفتاح API** (مُختبر)،
/// والصفحة الواحدة 100 عنصر ثم رمز استمرار.
class YoutubePlaylistResolver {
  YoutubePlaylistResolver({HttpPostJson? httpPost})
      : _post = httpPost ?? ioHttpPostJson;

  final HttpPostJson _post;

  static final Uri _browse =
      Uri.parse('https://www.youtube.com/youtubei/v1/browse?prettyPrint=false');

  /// حد أعلى للصفحات — قائمة بآلاف العناصر لا تُعرض في شاشة اختيار.
  static const maxPages = 12;

  Future<PlaylistPreview?> resolve(String playlistUrl) async {
    final id = PlaylistDetector.youtubePlaylistId(playlistUrl);
    if (id == null) return null;
    try {
      final first = await _browsePage({'browseId': 'VL$id'});
      final preview = InnertubeParser.parseBrowse(first);
      if (preview == null) return null;

      final tracks = [...preview.tracks];
      var token = InnertubeParser.continuationToken(first);
      for (var page = 1; page < maxPages && token != null; page++) {
        final next = await _browsePage({'continuation': token});
        final more = InnertubeParser.parseBrowse(next);
        if (more == null) break;
        tracks.addAll(more.tracks);
        token = InnertubeParser.continuationToken(next);
      }
      return PlaylistPreview(
        kind: preview.kind,
        title: preview.title,
        coverUrl: preview.coverUrl,
        tracks: tracks,
      );
    } on Object {
      return null;
    }
  }

  Future<Object?> _browsePage(Map<String, Object> payload) async {
    final body = await _post(_browse, {
      'context': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20260902.01.00',
          'hl': 'en',
        }
      },
      ...payload,
    });
    return json.decode(body);
  }
}
