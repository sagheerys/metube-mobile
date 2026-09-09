import 'package:flutter/widgets.dart';

import 'palette.dart';

export 'palette.dart';

/// Radii are "quiet and printed" (log §4): 28 for sheets, 16 to 18 for
/// cards, 12 to 13 for fields and icon buttons. Full pills only for round
/// chips.
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

/// The spacing scale, taken from the rhythm of the Wahaj references: page
/// gutter 18, content gap 13.
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

/// Motion: the single Wahaj curve.
abstract final class MTMotion {
  static const Curve ease = Cubic(0.32, 0.72, 0, 1);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 640);

  // Motion (log §4, 2026-09-02). **Softened on request: "unbalanced, calm
  // it down and make it smoother".**
  //
  // The principle: **quick on the way out, calm on the way in**. Motion is
  // glimpsed, not watched. Wahaj is a warm editorial identity, not a game
  // interface.
  //
  // The lesson from the first attempt: **distance tires the eye, not
  // duration.** A 14-point card slide and a page slide of 0.22 of the
  // screen width both read as a jump. The values are now roughly half of
  // that, and the work is carried mostly by the fade.

  /// A confident entrance: accelerates, then settles without overshoot.
  static const Curve entrance = Cubic(0.2, 0, 0, 1);

  /// A decisive exit. What is leaving does not deserve attention.
  static const Curve exit = Cubic(0.3, 0, 1, 1);

  /// A small element's pulse: badge, button, chip.
  static const Duration tap = Duration(milliseconds: 160);

  /// A full screen transition.
  static const Duration page = Duration(milliseconds: 240);

  /// Content appearing inside a screen.
  static const Duration reveal = Duration(milliseconds: 220);

  /// Slide offset for an element inside a screen, in points. Small on
  /// purpose.
  static const double slideNudge = 7;

  /// Page slide distance as a fraction of the page width.
  static const double pageSlide = 0.06;

  // Polish pass 2026-09-04, on the request "light, consistent touch
  // motion".

  /// A screen that rises like a sheet from the bottom, such as the audio
  /// screen opened from the mini player. Longer than [page] because it
  /// travels the full distance, and still under the agreed 320ms ceiling.
  static const Duration sheetPage = Duration(milliseconds: 300);

  /// How far an element shrinks while pressed. Glimpsed, not watched.
  static const double pressScale = 0.97;

  /// How far the outgoing icon shrinks when two icons swap.
  static const double iconSwapScale = 0.6;

  /// A downward drag past this distance closes the audio screen, in points.
  static const double dismissDragDistance = 120;

  /// Or a velocity past this, in points per second: a short flick is
  /// enough.
  static const double dismissFlingVelocity = 700;
}

/// The approved typography: Noto Kufi Arabic for headings (700/500) and
/// Tajawal for body text.
abstract final class MTType {
  static const String display = 'NotoKufiArabic';
  static const String body = 'Tajawal';

  /// The fonts live inside the mt_ui package, so every TextStyle has to
  /// pass
  /// `package`.
  static const String package = 'mt_ui';
}

/// **Fixed-width digits** for live counters.
///
/// **A documented trap (review 2026-09-02):** adding
/// `FontFeature.tabularFigures()` on its own does nothing here. Inspecting
/// the font binaries proved that **Tajawal has no `tnum` table** while Noto
/// Kufi Arabic does. A counter drawn in the body font keeps dancing with
/// every passing second however loudly the feature is requested.
///
/// So counters are drawn in the **heading** font, which actually supports
/// the feature, and only on changing numbers: time, size, speed. Never on
/// prose.
extension MTTabularFigures on TextStyle {
  TextStyle get tabular => copyWith(
        fontFamily: MTType.display,
        package: MTType.package,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Warm shadows, copied from the reference values.
abstract final class MTShadow {
  /// Daylight card shadow: 0 3 6 at 5% plus 0 30 60 -22 at 22%, in a warm
  /// brown.
  static const List<BoxShadow> card = [
    BoxShadow(
        color: Color(0x0D50371E), blurRadius: 6, offset: Offset(0, 3)),
    BoxShadow(
        color: Color(0x3850371E),
        blurRadius: 60,
        offset: Offset(0, 30),
        spreadRadius: -22),
  ];

  /// FAB shadow: 0 16 32 -10 in accentDeep at 55%, built from the palette.
  static List<BoxShadow> fab(MTPalette p) => [
        BoxShadow(
          color: p.accentDeep.withValues(alpha: 0.55),
          blurRadius: 32,
          offset: const Offset(0, 16),
          spreadRadius: -10,
        ),
      ];

  /// Mini player shadow: 0 18 40 -12 in ink at 50%.
  static List<BoxShadow> mini(MTPalette p) => [
        BoxShadow(
          color: p.ink.withValues(alpha: 0.5),
          blurRadius: 40,
          offset: const Offset(0, 18),
          spreadRadius: -12,
        ),
      ];
}
