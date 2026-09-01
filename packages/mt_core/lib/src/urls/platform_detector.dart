/// كاشف المنصات — **القائمة الواحدة** المعتمدة (م-4): أي شاشة أو ودجت
/// تحتاج اسم المنصة تمر من هنا، لا قوائم مكررة.
enum MediaPlatform {
  youtube('YouTube'),
  tiktok('TikTok'),
  instagram('Instagram'),
  soundcloud('SoundCloud'),
  x('X'),
  facebook('Facebook'),
  vimeo('Vimeo'),
  twitch('Twitch'),
  reddit('Reddit'),
  dailymotion('Dailymotion'),
  other('Other');

  const MediaPlatform(this.label);

  /// اسم عرض إنجليزي محايد — الترجمة العربية عبر arb في طبقة الواجهة.
  final String label;

  bool get isYouTube => this == MediaPlatform.youtube;

  /// المنصة من الرابط. الروابط القصيرة (vm./vt.tiktok، fb.watch،
  /// on.soundcloud) تُنسب لمنصتها قبل الحلّ حتى تعرضها الشارة فوراً.
  static MediaPlatform detect(String url) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return MediaPlatform.other;
    if (u.contains('youtube.com') || u.contains('youtu.be')) {
      return MediaPlatform.youtube;
    }
    if (u.contains('tiktok.com')) return MediaPlatform.tiktok;
    if (u.contains('instagram.com')) return MediaPlatform.instagram;
    if (u.contains('soundcloud.com')) return MediaPlatform.soundcloud;
    if (u.contains('twitter.com') || u.contains('x.com')) {
      return MediaPlatform.x;
    }
    if (u.contains('facebook.com') || u.contains('fb.watch')) {
      return MediaPlatform.facebook;
    }
    if (u.contains('vimeo.com')) return MediaPlatform.vimeo;
    if (u.contains('twitch.tv')) return MediaPlatform.twitch;
    if (u.contains('reddit.com')) return MediaPlatform.reddit;
    if (u.contains('dailymotion.com')) return MediaPlatform.dailymotion;
    return MediaPlatform.other;
  }

  /// هل الرابط لمنصة معروفة؟ (يغذي الزر الذكي م-2.)
  static bool isKnown(String url) => detect(url) != MediaPlatform.other;
}
