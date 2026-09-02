/// كاشف قوائم التشغيل — يغذي التوجيه التلقائي (م-5):
/// رابط قائمة ⇒ شاشة الدفعي، رابط مفرد ⇒ إضافة مباشرة.
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

  /// معرف قائمة YouTube من أي شكل رابط، أو null إن لم يكن قائمة حقيقية.
  ///
  /// **الاستثناءات مقصودة (2026-09-02):**
  /// - `RD…` قوائم **مزيج** يولّدها يوتيوب لكل مشاهد بلا عناصر ثابتة،
  ///   وردّ الخادم لها فارغ ⇒ كانت تُظهر «تعذّر تحميل هذه القائمة».
  /// - `WL` (المشاهدة لاحقاً) و`LL` (الإعجابات) خاصتان بحساب مسجَّل
  ///   الدخول ⇒ لا تُقرآن أبداً بلا اعتماد.
  ///
  /// الثلاثة تُعامل كرابط مفرد: يُحمَّل الفيديو نفسه بدل شاشة فارغة.
  static String? youtubePlaylistId(String url) {
    final id = Uri.tryParse(url)?.queryParameters['list'] ??
        RegExp(r'/playlist/([A-Za-z0-9_-]+)').firstMatch(url)?.group(1);
    if (id == null || id.isEmpty) return null;
    if (id.startsWith('RD') || id == 'WL' || id == 'LL') return null;
    return id;
  }
}
