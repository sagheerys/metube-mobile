/// كاشف قوائم التشغيل — يغذي التوجيه التلقائي (م-5):
/// رابط قائمة ⇒ شاشة الدفعي، رابط مفرد ⇒ إضافة مباشرة.
enum PlaylistKind { none, youtube, soundcloud }

abstract final class PlaylistDetector {
  static PlaylistKind detect(String url) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return PlaylistKind.none;

    if (u.contains('youtube.com') || u.contains('youtu.be')) {
      final query = Uri.tryParse(url)?.queryParameters;
      if ((query != null && (query['list']?.isNotEmpty ?? false)) ||
          u.contains('/playlist')) {
        return PlaylistKind.youtube;
      }
      return PlaylistKind.none;
    }

    if (u.contains('soundcloud.com') && u.contains('/sets/')) {
      return PlaylistKind.soundcloud;
    }

    return PlaylistKind.none;
  }

  static bool isPlaylist(String url) => detect(url) != PlaylistKind.none;
}
