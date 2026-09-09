import 'dart:convert';

import '../models/playlist_preview.dart';
import '../urls/playlist_detector.dart';
import 'http_fetch.dart';

/// SoundCloud (§4), **fragile by nature and isolated**: any failure
/// returns null and breaks nothing, since the link is passed to the server
/// as it is. There are no official API keys.
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

  /// The largest batch `/tracks?ids=` accepts before refusing.
  static const idsPerBatch = 50;

  /// A ceiling on completed tracks: an album of 432 tracks, which really
  /// does happen, needs no more than this on a selection screen.
  static const maxTracks = 400;

  /// A single track's cover through oEmbed, upscaling `-large.` to
  /// `-t500x500.`.
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

  /// Resolves a `/sets/` playlist from `window.__sc_hydration`, then
  /// **completes the partial tracks** through api-v2.
  ///
  /// **Field report 2026-09-02, "the album downloads strangely":**
  /// SoundCloud embeds the full object for only the first five or so
  /// tracks;
  /// the rest arrive as `{id, kind}` with no `permalink_url`, and the
  /// parser
  /// was dropping them silently, so an album of 432 tracks showed **5**.
  /// Completion happens here in batches of [idsPerBatch].
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

  /// Pure parsing of the hydration block, kept separate so it can be tested
  /// against real HTML samples.
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

  /// The ids of tracks that arrived **incomplete**, without a
  /// `permalink_url`.
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

  /// The complete tracks out of any array, whether hydration or an api-v2
  /// response.
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

  /// Extracts the client_id, 32 characters.
  ///
  /// **The first source is `apiClient` in the hydration block** (confirmed
  /// against the live site 2026-09-02): the three textual patterns no
  /// longer
  /// match anything on today's page, so completion failed before it began.
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
