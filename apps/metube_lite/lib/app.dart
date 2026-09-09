import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import 'di.dart';
import 'router.dart';

/// The MeTube Lite root: the Wahaj theme with the petrol bay accent, plus
/// localisation and the router. The identity is one and the difference is
/// functional only (`01-PRD.md` §1.4).
class LiteApp extends ConsumerWidget {
  const LiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final localeCode = ref.watch(settingsProvider.select((s) => s.localeCode));

    return MaterialApp.router(
      title: 'MeTube Lite',
      debugShowCheckedModeBanner: false,
      theme: mtTheme(MTVariant.lite, Brightness.light),
      darkTheme: mtTheme(MTVariant.lite, Brightness.dark),
      themeMode: themeMode,
      locale: localeCode == null ? null : Locale(localeCode),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      routerConfig: router,
      // **The system bars follow the theme**, without the contrast scrim
      // Android imposes behind the three navigation buttons, which cuts
      // across
      // the colour of the bottom bar.
      builder: (context, child) =>
          MTSystemBars(child: child ?? const SizedBox.shrink()),
    );
  }
}
