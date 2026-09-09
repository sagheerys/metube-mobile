import 'dart:ui';

/// The two app variants. Identical in everything except the accent colour
/// (log §4).
enum MTVariant { lite, superApp }

/// The Wahaj palette. Values are copied **verbatim** from the approved
/// design references. Derived values, the ones not stated there, are
/// marked with a `derived` comment.
class MTPalette {
  const MTPalette({
    required this.bg,
    required this.card,
    required this.cardAlt,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.line2,
    required this.accent,
    required this.accentDeep,
    required this.accentSoft,
    required this.accentInk,
    required this.onAccent,
    required this.offline,
    required this.offlineSoft,
    required this.offlineInk,
    required this.onServerSoft,
    required this.onServerInk,
    required this.ok,
    required this.err,
    required this.favorite,
    required this.favoriteSoft,
    required this.grainOpacity,
    this.night = false,
  });

  final Color bg;
  final Color card;
  final Color cardAlt;
  final Color ink;
  final Color ink2;
  final Color ink3;

  /// Hairline rules, which replace boxes in Wahaj.
  final Color line;
  final Color line2;

  /// The accent: ember in Super, petrol bay in Lite.
  final Color accent;
  final Color accentDeep;
  final Color accentSoft;
  final Color accentInk;
  final Color onAccent;

  /// Olive, which signals "offline" in Super.
  final Color offline;
  final Color offlineSoft;
  final Color offlineInk;

  /// Signals "on the server" (soft ember in Super).
  final Color onServerSoft;
  final Color onServerInk;

  final Color ok;
  final Color err;

  /// Favourites are crimson, independent of either accent colour.
  final Color favorite;
  final Color favoriteSoft;

  /// Film grain.
  final double grainOpacity;

  /// Is this a night palette? Only the mini player reads it today.
  final bool night;

  /// **The mini player is inverted by day and consistent by night**
  /// (decision 2026-09-05, after seeing it on a device).
  ///
  /// It used to be inverted in both: an elegant dark bar under a cream
  /// interface by day, and a **bright pale bar** under a black screen by
  /// night, a glare in a dark room. Inversion is a daylight idea by nature,
  /// so at night it follows the card instead.
  Color get miniBg => night ? card : ink;
  Color get miniInk => night ? ink : bg;
  Color get miniInkMuted => (night ? ink : bg).withValues(alpha: 0.55);

  /// The server status card stays espresso-dark in both themes (log §4).
  static const Color serverCardBg = Color(0xFF241B15);
  static const Color serverCardInk = Color(0xFFF4EBDF);

  // Always-dark constants. Full review 2026-09-02 found these hard-coded
  // in the screens, against rule 5: every colour comes from tokens, no
  // literals.

  /// The far end of the espresso playlist-card gradient, lighter than
  /// [serverCardBg].
  static const Color serverCardBgLift = Color(0xFF443327);

  /// The immersive landscape player scrim: near-opaque espresso over video.
  static const Color fullscreenScrim = Color(0xEB140F0C);

  /// System notification red. Used outside the widget tree, where there is
  /// no `context` and no `MTThemeX`, so it has to be an explicit constant.
  static const Color notificationError = Color(0xFFB3261E);

  static MTPalette of(MTVariant variant, Brightness brightness) =>
      switch ((variant, brightness)) {
        (MTVariant.superApp, Brightness.light) => superDay,
        (MTVariant.superApp, Brightness.dark) => superNight,
        (MTVariant.lite, Brightness.light) => liteDay,
        (MTVariant.lite, Brightness.dark) => liteNight,
      };

  // The shared daylight base.
  static const MTPalette superDay = MTPalette(
    bg: Color(0xFFFBF6EE),
    card: Color(0xFFFFFDF9),
    cardAlt: Color(0xFFF6EFE2), // مشتق: بين bg وcard لأرضية ثانوية
    ink: Color(0xFF2B211B),
    ink2: Color(0xAD2B211B), // rgba(43,33,27,.68)
    ink3: Color(0x732B211B), // rgba(43,33,27,.45)
    line: Color(0x1F2B211B), // rgba(43,33,27,.12)
    line2: Color(0x332B211B), // rgba(43,33,27,.20)
    accent: Color(0xFFC25E2E),
    accentDeep: Color(0xFF9E4517),
    accentSoft: Color(0xFFF6E4D6),
    accentInk: Color(0xFF8A3D14),
    onAccent: Color(0xFFFFF8F2),
    offline: Color(0xFF6B7A3F),
    offlineSoft: Color(0xFFEBEDDD),
    offlineInk: Color(0xFF4E5A2B),
    onServerSoft: Color(0xFFF6E4D6),
    onServerInk: Color(0xFF8A3D14),
    ok: Color(0xFF4E7A3F),
    err: Color(0xFFB0402F),
    favorite: Color(0xFFA83A3A),
    favoriteSoft: Color(0xFFFBE3E0),
    grainOpacity: 0.035,
  );

  // Espresso night.
  static const MTPalette superNight = MTPalette(
    bg: Color(0xFF1A130F),
    card: Color(0xFF241B15),
    cardAlt: Color(0xFF2B211A),
    ink: Color(0xFFF4EBDF),
    ink2: Color(0xA8F4EBDF), // rgba(.66)
    ink3: Color(0x6BF4EBDF), // rgba(.42)
    line: Color(0x17F4EBDF), // rgba(.09)
    line2: Color(0x2BF4EBDF), // rgba(.17)
    accent: Color(0xFFE0784A),
    accentDeep: Color(0xFFC25E2E),
    accentSoft: Color(0x24E0784A), // rgba(224,120,74,.14)
    accentInk: Color(0xFFF0A981),
    onAccent: Color(0xFF2B1207), // النص فوق لون الفعل ليلاً داكن لا أبيض
    offline: Color(0xFF95A55E),
    offlineSoft: Color(0x2695A55E), // rgba(.15)
    offlineInk: Color(0xFFC9D49A),
    onServerSoft: Color(0x24E0784A),
    onServerInk: Color(0xFFF0A981),
    ok: Color(0xFF7FAF6A),
    err: Color(0xFFE07A66),
    favorite: Color(0xFFFF9AA0),
    favoriteSoft: Color(0x24FF9AA0), // مشتق: soft ليلي بنمط البقية
    grainOpacity: 0.04,
    night: true,
  );

  // Lite by day: the same base plus petrol bay.
  static const MTPalette liteDay = MTPalette(
    bg: Color(0xFFFBF6EE),
    card: Color(0xFFFFFDF9),
    cardAlt: Color(0xFFF6EFE2), // مشتق
    ink: Color(0xFF2B211B),
    ink2: Color(0xAD2B211B),
    ink3: Color(0x732B211B),
    line: Color(0x1F2B211B),
    line2: Color(0x332B211B),
    accent: Color(0xFF2F6D74),
    accentDeep: Color(0xFF245A60),
    accentSoft: Color(0xFFDFEBEA),
    accentInk: Color(0xFF1F4D52),
    onAccent: Color(0xFFF2F8F7),
    offline: Color(0xFF6B7A3F),
    offlineSoft: Color(0xFFEBEDDD),
    offlineInk: Color(0xFF4E5A2B),
    onServerSoft: Color(0xFFDFEBEA),
    onServerInk: Color(0xFF1F4D52),
    ok: Color(0xFF4E7A3F),
    err: Color(0xFFB0402F),
    favorite: Color(0xFFA83A3A),
    favoriteSoft: Color(0xFFFBE3E0),
    grainOpacity: 0.035,
  );

  // Lite by night: coffee with a sea-blue cast.
  static const MTPalette liteNight = MTPalette(
    bg: Color(0xFF141A1B),
    card: Color(0xFF1E2627),
    cardAlt: Color(0xFF253030), // مشتق: درجة أعلى من card
    ink: Color(0xFFEAF1F0),
    ink2: Color(0xA8EAF1F0), // rgba(.66)
    ink3: Color(0x6BEAF1F0), // rgba(.42)
    line: Color(0x17EAF1F0), // rgba(.09)
    line2: Color(0x2BEAF1F0), // rgba(.17)
    accent: Color(0xFF6FB3BA),
    accentDeep: Color(0xFF569CA3), // مشتق
    accentSoft: Color(0x246FB3BA), // rgba(111,179,186,.14)
    accentInk: Color(0xFFA5D2D6),
    onAccent: Color(0xFF0E2325), // داكن فوق لون الفعل ليلاً
    offline: Color(0xFF95A55E),
    offlineSoft: Color(0x2695A55E),
    offlineInk: Color(0xFFC9D49A),
    onServerSoft: Color(0x246FB3BA),
    onServerInk: Color(0xFFA5D2D6),
    ok: Color(0xFF7FAF6A),
    err: Color(0xFFE07A66),
    favorite: Color(0xFFFF9AA0),
    favoriteSoft: Color(0x24FF9AA0),
    grainOpacity: 0.04,
    night: true,
  );
}
