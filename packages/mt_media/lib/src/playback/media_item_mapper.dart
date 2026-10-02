import 'package:audio_service/audio_service.dart';
import 'package:mt_core/mt_core.dart';

import '../models/playlist_item.dart';

/// Converts [PlaylistItem] to and from [MediaItem] for the media
/// notification and the lock screen. The id is always the canonicalUrl, so
/// the key stays the same across every layer.
extension PlaylistItemMediaItem on PlaylistItem {
  ///
  /// [playlistName] is the saved playlist the queue came from, if any.
  MediaItem toMediaItem({String? playlistName}) => MediaItem(
    id: canonicalUrl,
    title: title,
    artist: uploader,
    album: _secondLine(playlistName),
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

  /// **A second line when there is no artist** (design review
  /// 2026-09-25). Instagram and SoundCloud clips often come without an
  /// uploader, and the notification then showed a title over an empty
  /// line. Android fills that line from the artist and falls back to the
  /// album, so the album carries where the clip plays from: the playlist,
  /// or else the platform. A clip with an artist keeps exactly what it
  /// showed before.
  String? _secondLine(String? playlistName) {
    if (uploader?.trim().isNotEmpty ?? false) return null;
    if (playlistName != null && playlistName.trim().isNotEmpty) {
      return playlistName;
    }
    final platform = MediaPlatform.detect(canonicalUrl);
    return platform == MediaPlatform.other ? null : platform.label;
  }

  /// **An absolute path is artwork too** (field report 2026-09-19: "some
  /// audio clips have a cover, and it shows in the app but not in the
  /// notification or on the lock screen").
  ///
  /// A video's cover arrives from the server as `https://…` and passed. An
  /// audio clip's cover is the one **extracted from the file itself** and
  /// written to disk by the library enricher, so it arrives as
  /// `/data/.../thumbnails/x.jpg` — no scheme, thrown away here, and the
  /// notification fell back to the app icon. `audio_service` decodes a file
  /// path happily (`BitmapFactory.decodeFile`); it only ever needed the
  /// `file://` in front of it.
  ///
  /// A relative path is still refused: it is a bug upstream, not artwork.
  static Uri? _artUri(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('/')) return Uri.file(trimmed);
    final uri = Uri.tryParse(trimmed);
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
