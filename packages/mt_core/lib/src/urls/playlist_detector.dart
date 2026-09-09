/// Playlist detection, which feeds automatic routing: a playlist URL opens
/// the batch screen, a single URL is added directly.
enum PlaylistKind { none, youtube, soundcloud }

abstract final class PlaylistDetector {
  static PlaylistKind detect(String url) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return PlaylistKind.none;

    if (u.contains('youtube.com') || u.contains('youtu.be')) {
      return youtubePlaylistId(url) == null
          ? PlaylistKind.none
          : PlaylistKind.youtube;
    }

    if (u.contains('soundcloud.com') && u.contains('/sets/')) {
      return PlaylistKind.soundcloud;
    }

    return PlaylistKind.none;
  }

  static bool isPlaylist(String url) => detect(url) != PlaylistKind.none;

  /// The YouTube playlist id from any URL shape, or null when it is not a
  /// real playlist.
  ///
  /// **The exclusions are deliberate (2026-09-02):**
  /// - `RD…` are **mix** playlists YouTube generates per viewer with no
  /// fixed items, and the server returns nothing for them, so they showed
  /// "could not load this playlist".
  /// - `WL` (Watch Later) and `LL` (Liked) belong to a signed-in account
  ///   and
  /// are never readable without credentials.
  ///
  /// All three are treated as a single link: the video itself downloads
  /// instead of an empty screen.
  static String? youtubePlaylistId(String url) {
    final id =
        Uri.tryParse(url)?.queryParameters['list'] ??
        RegExp(r'/playlist/([A-Za-z0-9_-]+)').firstMatch(url)?.group(1);
    if (id == null || id.isEmpty) return null;
    if (id.startsWith('RD') || id == 'WL' || id == 'LL') return null;
    return id;
  }
}
