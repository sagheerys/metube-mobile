import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import '../widgets/mt_motion.dart';

/// Theme extension: carries the Wahaj palette to every widget through
/// `MTThemeX.of(context)` instead of any literal colour (rule 5).
class MTThemeX extends ThemeExtension<MTThemeX> {
  const MTThemeX({required this.palette, required this.variant});

  final MTPalette palette;
  final MTVariant variant;

  static MTThemeX of(BuildContext context) =>
      Theme.of(context).extension<MTThemeX>()!;

  @override
  MTThemeX copyWith({MTPalette? palette, MTVariant? variant}) => MTThemeX(
    palette: palette ?? this.palette,
    variant: variant ?? this.variant,
  );

  @override
  MTThemeX lerp(MTThemeX? other, double t) => t < 0.5 ? this : other ?? this;
}

/// The Wahaj theme. **A documented lesson**: the five surfaceContainer*
/// roles must be set explicitly, or Material 3 imposes its own greys over
/// the cream ground.
ThemeData mtTheme(MTVariant variant, Brightness brightness) {
  final p = MTPalette.of(variant, brightness);
  final isDark = brightness == Brightness.dark;

  // The warm surface ladder, derived from bg to card to cardAlt at the
  // palette's own hue.
  final (lowest, low, container, high, highest) = isDark
      ? variant == MTVariant.lite
            ? (
                const Color(0xFF101516),
                const Color(0xFF1A2122),
                const Color(0xFF1E2627),
                const Color(0xFF253030),
                const Color(0xFF2C3839),
              )
            : (
                const Color(0xFF16100C),
                const Color(0xFF1F1712),
                const Color(0xFF241B15),
                const Color(0xFF2B211A),
                const Color(0xFF332720),
              )
      : (
          const Color(0xFFFFFDF9),
          const Color(0xFFFAF3E7),
          const Color(0xFFF6EFE2),
          const Color(0xFFF1E8D8),
          const Color(0xFFECE1CE),
        );

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: p.accentSoft,
    onPrimaryContainer: p.accentInk,
    secondary: p.offline,
    onSecondary: p.bg,
    secondaryContainer: p.offlineSoft,
    onSecondaryContainer: p.offlineInk,
    tertiary: p.favorite,
    onTertiary: p.favoriteSoft,
    error: p.err,
    onError: p.bg,
    surface: p.bg,
    onSurface: p.ink,
    onSurfaceVariant: p.ink2,
    outline: p.line2,
    outlineVariant: p.line,
    surfaceContainerLowest: lowest,
    surfaceContainerLow: low,
    surfaceContainer: container,
    surfaceContainerHigh: high,
    surfaceContainerHighest: highest,
    inverseSurface: p.miniBg,
    onInverseSurface: p.miniInk,
    inversePrimary: p.accentSoft,
    shadow: const Color(0xFF50371E),
    scrim: p.ink.withValues(alpha: 0.5),
  );

  TextStyle display(double size, FontWeight weight) => TextStyle(
    fontFamily: MTType.display,
    package: MTType.package,
    fontWeight: weight,
    fontSize: size,
    color: p.ink,
    height: 1.4,
  );
  TextStyle body(double size, FontWeight weight, {Color? color}) => TextStyle(
    fontFamily: MTType.body,
    package: MTType.package,
    fontWeight: weight,
    fontSize: size,
    color: color ?? p.ink,
    height: 1.55,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: 'packages/${MTType.package}/${MTType.body}',
    splashFactory: InkSparkle.splashFactory,
    // Screen transitions slide horizontally and respect the text direction,
    // instead of the default vertical rise that says nothing about how the
    // two screens relate.
    pageTransitionsTheme: mtPageTransitionsTheme,
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    textTheme: TextTheme(
      headlineLarge: display(24, FontWeight.w700),
      headlineMedium: display(20, FontWeight.w700),
      titleLarge: display(17, FontWeight.w700),
      titleMedium: display(14, FontWeight.w700),
      titleSmall: display(12.5, FontWeight.w500),
      bodyLarge: body(15, FontWeight.w400),
      bodyMedium: body(13.5, FontWeight.w400),
      bodySmall: body(11.5, FontWeight.w400, color: p.ink3),
      labelLarge: body(13.5, FontWeight.w700),
      labelMedium: body(12.5, FontWeight.w500),
      labelSmall: body(10.5, FontWeight.w500, color: p.ink3),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: display(24, FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTRadius.card),
        side: BorderSide(color: p.line),
      ),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: p.ink,
      side: BorderSide(color: p.line2),
      // **Label colour follows the state** (full review 2026-09-02): a
      // selected chip is painted with `p.ink` as its background and its
      // label was `p.ink2`, dark ink on dark ink, so **a selected tag could
      // not be read**. Screens that passed their own `labelStyle` were
      // hiding the defect; the tags sheet, which uses a bare `FilterChip`,
      // exposed it.
      labelStyle: body(12.5, FontWeight.w500).copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.bg : p.ink2,
        ),
      ),
      checkmarkColor: p.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTRadius.chip),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MTSpace.md,
        vertical: MTSpace.xs,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      hintStyle: body(13.5, FontWeight.w400, color: p.ink3),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MTSpace.lg,
        vertical: MTSpace.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MTRadius.field),
        borderSide: BorderSide(color: p.line2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MTRadius.field),
        borderSide: BorderSide(color: p.line2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MTRadius.field),
        borderSide: BorderSide(color: p.accent, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        textStyle: body(13.5, FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MTRadius.fab),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: MTSpace.xl,
          vertical: MTSpace.md,
        ),
      ),
    ),
    // Material 3 tints the selected state with secondaryContainer, which is
    // the olive that means "offline" in this design language (log §4).
    // Corrected to the accent colour.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accentSoft
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.accentInk : p.ink2,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: p.line2)),
        textStyle: WidgetStatePropertyAll(body(13, FontWeight.w500)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.bg,
      indicatorColor: Colors.transparent,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        body(11.5, FontWeight.w500, color: p.ink2),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? p.accent : p.ink3,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      // **One drag handle for all eighteen sheets** (review 2026-09-02: not
      // a single sheet had one). Setting it in the theme rather than in
      // each sheet is what stops the nineteenth sheet from being built
      // without one, which is exactly how an interface starts to look
      // assembled from different eras.
      showDragHandle: true,
      dragHandleColor: p.line2,
      dragHandleSize: const Size(38, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MTRadius.sheet),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.miniBg,
      contentTextStyle: body(13.5, FontWeight.w500, color: p.miniInk),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTRadius.card),
      ),
    ),
    extensions: [MTThemeX(palette: p, variant: variant)],
  );
}
