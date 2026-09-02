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

  /// أكبر دفعة تقبلها `/tracks?ids=` قبل أن تُرفض.
  static const idsPerBatch = 50;

  /// حد أعلى للمقاطع المُكمَّلة — ألبوم بـ432 مقطعاً (وارد فعلاً) لا
  /// يحتاج أكثر من هذا في شاشة اختيار.
  static const maxTracks = 400;

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

  /// حل قائمة `/sets/` من `window.__sc_hydration` ثم **إكمال المقاطع
  /// الناقصة** عبر api-v2.
  ///
  /// **بلاغ المالك 2026-09-02 «الألبوم يُحمَّل بطريقة غريبة»:** ساوندكلاود
  /// يضمّن الكائن الكامل لأول ~5 مقاطع فقط، والبقية تصل كـ`{id, kind}`
  /// بلا `permalink_url` — وكان المحلل يُسقطها بصمت، فألبوم من 432 مقطعاً
  /// يظهر **5**. الإكمال هنا بدفعات من [idsPerBatch].
  Future<PlaylistPreview?> resolveSet(String setUrl) async {
    try {
      final html = await _httpGet(Uri.parse(setUrl));
      final playlist = parseHydration(html);
      if (playlist == null) return null;
      final pending = pendingTrackIds(html);
      if (pending.isEmpty) return playlist;

      final clientId = extractClientId(html);
      if (clientId == null) return playlist;
      final filled = await _fetchTracks(pending, clientId);
      if (filled.isEmpty) return playlist;
      return PlaylistPreview(
        kind: playlist.kind,
        title: playlist.title,
        coverUrl: playlist.coverUrl,
        tracks: [...playlist.tracks, ...filled],
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<PlaylistTrack>> _fetchTracks(
      List<int> ids, String clientId) async {
    final out = <PlaylistTrack>[];
    for (var i = 0; i < ids.length; i += idsPerBatch) {
      final batch = ids.skip(i).take(idsPerBatch).join(',');
      final body = await _httpGet(Uri.parse(
          'https://api-v2.soundcloud.com/tracks?ids=$batch&client_id=$clientId'));
      final decoded = json.decode(body);
      if (decoded is! List) break;
      out.addAll(tracksOf(decoded));
    }
    return out;
  }

  /// تحليل خالص لكتلة hydration — منفصل ليُختبر بعينات HTML حقيقية.
  static PlaylistPreview? parseHydration(String html) {
    final data = _playlistData(html);
    if (data == null) return null;
    return PlaylistPreview(
      kind: PlaylistKind.soundcloud,
      title: data['title']?.toString() ?? '',
      coverUrl: _artOf(data),
      tracks: tracksOf(data['tracks'] as List? ?? const []),
    );
  }

  /// معرفات المقاطع التي وصلت **ناقصة** (بلا `permalink_url`).
  static List<int> pendingTrackIds(String html) {
    final data = _playlistData(html);
    final tracks = data?['tracks'] as List? ?? const [];
    return [
      for (final track in tracks)
        if (track is Map &&
            track['permalink_url'] == null &&
            track['id'] is num)
          (track['id'] as num).toInt(),
    ].take(maxTracks).toList();
  }

  /// المقاطع الكاملة من أي مصفوفة (hydration أو ردّ api-v2).
  static List<PlaylistTrack> tracksOf(List<dynamic> raw) => [
        for (final track in raw)
          if (track is Map && track['permalink_url'] != null)
            PlaylistTrack(
              url: track['permalink_url'].toString(),
              title: track['title']?.toString() ?? '',
              duration: track['duration'] is num
                  ? Duration(milliseconds: (track['duration'] as num).toInt())
                  : null,
              thumbnail: _artOf(track),
            ),
      ];

  /// استخراج client_id (32 محرفاً).
  ///
  /// **المصدر الأول هو `apiClient` في hydration** (مُثبت على الموقع
  /// الحقيقي 2026-09-02): الأنماط النصية الثلاثة لم تعد تطابق شيئاً في
  /// صفحة اليوم، فكان الإكمال يسقط قبل أن يبدأ.
  static String? extractClientId(String content) {
    final hydration = _hydration(content);
    for (final entry in hydration) {
      if (entry is Map && entry['hydratable'] == 'apiClient') {
        final id = (entry['data'] as Map?)?['id']?.toString();
        if (id != null && id.length >= 24) return id;
      }
    }
    for (final pattern in _clientIdPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static List<dynamic> _hydration(String html) {
    final match = _hydrationPattern.firstMatch(html);
    if (match == null) return const [];
    try {
      final decoded = json.decode(match.group(1)!);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  static Map<dynamic, dynamic>? _playlistData(String html) {
    for (final entry in _hydration(html)) {
      if (entry is! Map || entry['hydratable'] != 'playlist') continue;
      final data = entry['data'];
      return data is Map ? data : null;
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
