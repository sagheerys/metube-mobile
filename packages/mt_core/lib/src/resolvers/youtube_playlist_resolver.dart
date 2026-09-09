import 'dart:convert';

import '../models/playlist_preview.dart';
import '../urls/playlist_detector.dart';
import 'http_fetch.dart';
import 'innertube_parser.dart';

/// YouTube playlists, fail-safe: null on any error, and the batch screen
/// shows a message.
///
/// **Written against InnerTube directly rather than
/// `youtube_explode_dart`** (field report 2026-09-02: "the playlist shows
/// an empty page"). Running it for real proved that
/// `yt.playlists.getVideos()` emits **zero items** for a playlist counting
/// 19, in 2.5.3 and in the newest 3.1.0 alike, because YouTube replaced
/// `playlistVideoRenderer` with `lockupViewModel`. The earlier project
/// uses the same package, so the defect is inherited rather than new.
///
/// The `browse` endpoint with `browseId: VL<id>` works **without an API
/// key** (tested), one page holds 100 items, and then a continuation
/// token follows.
class YoutubePlaylistResolver {
  YoutubePlaylistResolver({HttpPostJson? httpPost})
      : _post = httpPost ?? ioHttpPostJson;

  final HttpPostJson _post;

  static final Uri _browse =
      Uri.parse('https://www.youtube.com/youtubei/v1/browse?prettyPrint=false');

  /// A page ceiling: a playlist with thousands of items is not shown on a
  /// selection screen.
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
