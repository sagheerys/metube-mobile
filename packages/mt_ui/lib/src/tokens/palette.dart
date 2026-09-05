import 'dart:ui';

/// نسختا التطبيق — تتطابقان في كل شيء عدا لون الفعل (سجل §4).
enum MTVariant { lite, superApp }

/// لوحة «وهج» — القيم منسوخة **حرفياً** من مراجع Open Design المعتمدة
/// (`direction-3-wahaj` + `wahaj-dark-mode` + `wahaj-lite-screens`).
/// القيم المشتقة (غير المنصوصة) معلمة بتعليق `مشتق`.
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

  /// الفواصل الشعرية — بديل الصناديق في «وهج».
  final Color line;
  final Color line2;

  /// لون الفعل: وهج في Super · خليج بترولي في Lite.
  final Color accent;
  final Color accentDeep;
  final Color accentSoft;
  final Color accentInk;
  final Color onAccent;

  /// الزيتوني — دلالة «دون اتصال» في Super.
  final Color offline;
  final Color offlineSoft;
  final Color offlineInk;

  /// دلالة «على السيرفر» (وهج soft في Super).
  final Color onServerSoft;
  final Color onServerInk;

  final Color ok;
  final Color err;

  /// المفضلة ♥ قرمزي مستقل عن لوني الفعل (م-36).
  final Color favorite;
  final Color favoriteSoft;

  /// حبيبات الفيلم.
  final double grainOpacity;

  /// هل هذه لوحة ليل؟ — يقرؤها المشغل المصغر وحده اليوم.
  final bool night;

  /// **المشغل المصغر: معكوس نهاراً، متّسق ليلاً** (قرار المالك
  /// 2026-09-05 بعد رؤيته على الجهاز).
  ///
  /// كان معكوساً في الوضعين: شريط داكن أنيق تحت واجهة كريمية نهاراً —
  /// وشريط **فاتح ساطع** تحت شاشة سوداء ليلاً، وهجٌ في غرفة مظلمة.
  /// العكس فكرةٌ نهارية بطبعها، فليلاً يتبع البطاقة.
  Color get miniBg => night ? card : ink;
  Color get miniInk => night ? ink : bg;
  Color get miniInkMuted => (night ? ink : bg).withValues(alpha: 0.55);

  /// بطاقة حالة السيرفر إسبريسو داكنة دائماً (سجل §4).
  static const Color serverCardBg = Color(0xFF241B15);
  static const Color serverCardInk = Color(0xFFF4EBDF);

  // ── ثوابت داكنة دائمة (فحص شامل 2026-09-02: كانت مثبتة في الشاشات
  // مخالفةً للقاعدة 5 — «كل لون من tokens، صفر قيمة مثبتة») ──────────

  /// طرف تدرّج بطاقة القائمة الإسبريسو — أفتح من [serverCardBg].
  static const Color serverCardBgLift = Color(0xFF443327);

  /// حجاب المشغل العرضي الغامر: إسبريسو شبه معتم فوق الفيديو.
  static const Color fullscreenScrim = Color(0xEB140F0C);

  /// أحمر إشعارات النظام — يُستعمل خارج شجرة الودجت (لا `context`
  /// ولا `MTThemeX`)، فيلزم أن يكون ثابتاً صريحاً.
  static const Color notificationError = Color(0xFFB3261E);

  static MTPalette of(MTVariant variant, Brightness brightness) =>
      switch ((variant, brightness)) {
        (MTVariant.superApp, Brightness.light) => superDay,
        (MTVariant.superApp, Brightness.dark) => superNight,
        (MTVariant.lite, Brightness.light) => liteDay,
        (MTVariant.lite, Brightness.dark) => liteNight,
      };

  // ── الأساس النهاري المشترك ──
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

  // ── ليل «إسبريسو» ──
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

  // ── Lite نهاراً: نفس الأساس + خليج بترولي ──
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

  // ── Lite ليلاً: «بُن بزُرقة البحر» ──
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
