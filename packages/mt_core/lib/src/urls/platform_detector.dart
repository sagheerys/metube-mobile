/// Platform detection: **the single approved list**. Any screen or widget
/// needing a platform name comes through here; there are no duplicate
/// lists.
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

  /// A neutral English display name; the Arabic translation lives in the
  /// arb
  /// files in the interface layer.
  final String label;

  bool get isYouTube => this == MediaPlatform.youtube;

  /// The platform from a URL. Short links (vm./vt.tiktok, fb.watch,
  /// on.soundcloud) are attributed to their platform before resolution, so
  /// the badge can show it immediately.
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

  /// Is this URL from a known platform? Feeds the smart button.
  static bool isKnown(String url) => detect(url) != MediaPlatform.other;
}
