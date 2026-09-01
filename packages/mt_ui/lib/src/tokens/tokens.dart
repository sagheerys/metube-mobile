import 'package:flutter/widgets.dart';

import 'palette.dart';

export 'palette.dart';

/// الأقطار «هادئة مطبوعة» (سجل §4): 28 أوراق · 16–18 بطاقات ·
/// 12–13 حقول وأزرار أيقونية — لا حبوب كاملة إلا للرقاقات الدائرية.
abstract final class MTRadius {
  static const double sheet = 28;
  static const double card = 16;
  static const double cardLg = 18;
  static const double field = 13;
  static const double iconButton = 13;
  static const double thumb = 12;
  static const double chip = 10;
  static const double fab = 16;
  static const double mini = 18;
  static const double badge = 6;
  static const double pill = 999;
}

/// سلم المسافات — من إيقاع مراجع «وهج» (فراغ الصفحة 18، فجوة المحتوى 13).
abstract final class MTSpace {
  static const double xxs = 4;
  static const double xs = 7;
  static const double sm = 10;
  static const double md = 13;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 26;
  static const double pagePad = 18;
  static const double gap = 13;
}

/// الحركة — منحنى «وهج» الواحد.
abstract final class MTMotion {
  static const Curve ease = Cubic(0.32, 0.72, 0, 1);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 640);

  // ── الحركة (سجل §4 · 2026-09-02 · **خُففت بطلب المالك: «غير متزنة،
  // خففها واجعلها أكثر سلاسة»**) ─────────────────────────────────────
  // المبدأ: **سريع عند الخروج، هادئ عند الدخول**، والحركة تُلمَح ولا
  // تُشاهَد — «وهج» هوية تحريرية دافئة لا واجهة ألعاب.
  //
  // الدرس من المحاولة الأولى: **المسافة هي ما يُتعب العين لا المدة.**
  // انزلاق 14 نقطة للبطاقة و0.22 من عرض الشاشة للصفحة كانا يُقرآن
  // «قفزة». القيم الآن نصف ذلك تقريباً، والاعتماد الأكبر على التلاشي.

  /// دخول مؤكَّد: يتسارع ثم يستقر بلا تجاوز.
  static const Curve entrance = Cubic(0.2, 0, 0, 1);

  /// خروج حاسم — المغادر لا يستحق انتباهاً.
  static const Curve exit = Cubic(0.3, 0, 1, 1);

  /// نبضة عنصر صغير (شارة، زر، رقاقة).
  static const Duration tap = Duration(milliseconds: 160);

  /// انتقال شاشة كاملة.
  static const Duration page = Duration(milliseconds: 240);

  /// ظهور محتوى داخل الشاشة.
  static const Duration reveal = Duration(milliseconds: 220);

  /// إزاحة انزلاق عنصر داخلي (نقاط) — صغيرة عمداً.
  static const double slideNudge = 7;

  /// نسبة انزلاق الصفحة من عرضها.
  static const double pageSlide = 0.06;
}

/// الطباعة المعتمدة: عناوين Noto Kufi Arabic (700/500) · نصوص Tajawal.
abstract final class MTType {
  static const String display = 'NotoKufiArabic';
  static const String body = 'Tajawal';

  /// الخطوط داخل حزمة mt_ui — يلزم تمرير package لكل TextStyle.
  static const String package = 'mt_ui';
}

/// الظلال الدافئة — منسوخة من قيم المراجع.
abstract final class MTShadow {
  /// ظل البطاقة النهاري: 0 3 6 ٥٪ + 0 30 60 -22 ٢٢٪ بلون بُني دافئ.
  static const List<BoxShadow> card = [
    BoxShadow(
        color: Color(0x0D50371E), blurRadius: 6, offset: Offset(0, 3)),
    BoxShadow(
        color: Color(0x3850371E),
        blurRadius: 60,
        offset: Offset(0, 30),
        spreadRadius: -22),
  ];

  /// ظل FAB: 0 16 32 -10 بلون accentDeep ٥٥٪ — يُبنى من اللوحة.
  static List<BoxShadow> fab(MTPalette p) => [
        BoxShadow(
          color: p.accentDeep.withValues(alpha: 0.55),
          blurRadius: 32,
          offset: const Offset(0, 16),
          spreadRadius: -10,
        ),
      ];

  /// ظل المشغل المصغر: 0 18 40 -12 بحبر ٥٠٪.
  static List<BoxShadow> mini(MTPalette p) => [
        BoxShadow(
          color: p.ink.withValues(alpha: 0.5),
          blurRadius: 40,
          offset: const Offset(0, 18),
          spreadRadius: -12,
        ),
      ];
}
