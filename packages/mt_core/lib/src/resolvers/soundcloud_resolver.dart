import 'dart:convert';

import '../models/playlist_preview.dart';
import '../urls/playlist_detector.dart';
import 'http_fetch.dart';

/// SoundCloud (§4) — **هش بطبيعته ومعزول**: أي فشل يعيد null ولا يكسر
/// شيئاً (الرابط يُمرَّر للسيرفر كما هو). لا مفاتيح API رسمية.
class SoundCloudResolver {
  SoundCloudResolver({HttpGetString? httpGet})
      : _httpGet = httpGet ?? ioHttpGetString;

  final HttpGetString _httpGet;

  static final RegExp _hydrationPattern = RegExp(
    r'window\.__sc_hydration\s*=\s*(\[.+?\])\s*;',
    dotAll: true,
  );
  static final List<RegExp> _clientIdPatterns = [
    RegExp(r'client_id\s*:\s*"([a-zA-Z0-9]{32})"'),
    RegExp(r'"client_id"\s*:\s*"([a-zA-Z0-9]{32})"'),
    RegExp(r'client_id=([a-zA-Z0-9]{32})'),
  ];

  /// غلاف مقطع مفرد عبر oEmbed مع تكبير `-large.` إلى `-t500x500.`.
  Future<String?> trackArtwork(String trackUrl) async {
    try {
      final body = await _httpGet(Uri.parse(
          'https://soundcloud.com/oembed?format=json&url=${Uri.encodeComponent(trackUrl)}'));
      final decoded = json.decode(body);
      if (decoded is! Map) return null;
      final thumb = decoded['thumbnail_url']?.toString();
      return thumb == null ? null : upscaleArtwork(thumb);
    } catch (_) {
      return null;
    }
  }

  /// حل قائمة `/sets/` بتحليل `window.__sc_hydration` من HTML الصفحة.
  Future<PlaylistPreview?> resolveSet(String setUrl) async {
    try {
      final html = await _httpGet(Uri.parse(setUrl));
      final playlist = parseHydration(html);
      if (playlist == null) return null;
      return playlist;
    } catch (_) {
      return null;
    }
  }

  /// تحليل خالص لكتلة hydration — منفصل ليُختبر بعينات HTML حقيقية.
  static PlaylistPreview? parseHydration(String html) {
    final match = _hydrationPattern.firstMatch(html);
    if (match == null) return null;
    try {
      final hydration = json.decode(match.group(1)!);
      if (hydration is! List) return null;
      for (final entry in hydration) {
        if (entry is! Map || entry['hydratable'] != 'playlist') continue;
        final data = entry['data'];
        if (data is! Map) return null;
        return PlaylistPreview(
          kind: PlaylistKind.soundcloud,
          title: data['title']?.toString() ?? '',
          coverUrl: _artOf(data),
          tracks: [
            for (final track in (data['tracks'] as List? ?? const []))
              if (track is Map && track['permalink_url'] != null)
                PlaylistTrack(
                  url: track['permalink_url'].toString(),
                  title: track['title']?.toString() ?? '',
                  duration: track['duration'] is num
                      ? Duration(
                          milliseconds: (track['duration'] as num).toInt())
                      : null,
                  thumbnail: _artOf(track),
                ),
          ],
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// استخراج client_id (32 محرفاً) من HTML أو حزم JS — للـ fallback عبر
  /// api-v2 عندما تكون عناصر hydration ناقصة.
  static String? extractClientId(String content) {
    for (final pattern in _clientIdPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static String? _artOf(Map<dynamic, dynamic> data) {
    final art = (data['artwork_url'] ?? (data['user'] as Map?)?['avatar_url'])
        ?.toString();
    return art == null ? null : upscaleArtwork(art);
  }

  static String upscaleArtwork(String url) =>
      url.replaceAll('-large.', '-t500x500.');
}
