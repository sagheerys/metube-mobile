import 'package:audio_service/audio_service.dart';

import '../models/playlist_item.dart';

/// Converts [PlaylistItem] to and from [MediaItem] for the media
/// notification and the lock screen. The id is always the canonicalUrl, so
/// the key stays the same across every layer.
extension PlaylistItemMediaItem on PlaylistItem {
  MediaItem toMediaItem() => MediaItem(
        id: canonicalUrl,
        title: title,
        artist: uploader,
        duration: duration,
        artUri: _artUri(artworkUrl),
        playable: true,
        extras: {
          'localPath': localPath,
          'filename': serverFilename,
          'isAudio': isAudio,
          if (aspectRatio != null) 'aspectRatio': aspectRatio,
        },
      );

  static Uri? _artUri(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    return uri == null || !uri.hasScheme ? null : uri;
  }
}

/// The reverse direction, used when commands arrive from the notification
/// carrying only an id.
PlaylistItem? playlistItemFromMediaItem(MediaItem item) {
  final extras = item.extras ?? const {};
  final ratio = extras['aspectRatio'];
  return PlaylistItem(
    canonicalUrl: item.id,
    title: item.title,
    uploader: item.artist,
    artworkUrl: item.artUri?.toString(),
    localPath: extras['localPath'] as String?,
    serverFilename: extras['filename'] as String?,
    isAudio: extras['isAudio'] == true,
    duration: item.duration,
    aspectRatio: ratio is num ? ratio.toDouble() : null,
  );
}
