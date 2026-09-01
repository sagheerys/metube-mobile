import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/playlist_preview.dart';
import '../urls/playlist_detector.dart';

/// قوائم YouTube عبر youtube_explode_dart — فشل-آمن: null عند أي خطأ
/// (شاشة الدفعي تعرض رسالة، ولا شيء ينكسر).
class YoutubePlaylistResolver {
  /// مصنع قابل للحقن في الاختبارات.
  YoutubePlaylistResolver({YoutubeExplode Function()? clientFactory})
      : _clientFactory = clientFactory ?? YoutubeExplode.new;

  final YoutubeExplode Function() _clientFactory;

  Future<PlaylistPreview?> resolve(String playlistUrl) async {
    final YoutubeExplode yt;
    try {
      yt = _clientFactory();
    } catch (_) {
      return null;
    }
    try {
      final id = PlaylistId(playlistUrl);
      final meta = await yt.playlists.get(id);
      final tracks = <PlaylistTrack>[];
      await for (final video in yt.playlists.getVideos(id)) {
        tracks.add(PlaylistTrack(
          url: video.url,
          title: video.title,
          duration: video.duration,
          thumbnail: video.thumbnails.mediumResUrl,
        ));
      }
      return PlaylistPreview(
        kind: PlaylistKind.youtube,
        title: meta.title,
        coverUrl: tracks.isEmpty ? null : tracks.first.thumbnail,
        tracks: tracks,
      );
    } catch (_) {
      return null;
    } finally {
      yt.close();
    }
  }
}
