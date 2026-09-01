import 'package:audio_service/audio_service.dart';

import '../models/playlist_item.dart';

/// تحويل [PlaylistItem] ⇄ [MediaItem] لإشعار الوسائط وشاشة القفل.
/// المعرف هو canonicalUrl دائماً فيبقى المفتاح واحداً عبر الطبقات.
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

/// المسار العكسي — يُستعمل حين تصل الأوامر من الإشعار بمعرف فقط.
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
