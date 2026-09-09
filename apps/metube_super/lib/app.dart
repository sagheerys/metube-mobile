import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import 'di.dart';
import 'features/settings/auto_switch.dart';
import 'router.dart';

/// The MeTube Super root: the Wahaj theme in Super's identity, plus
/// localisation and the router.
class SuperApp extends ConsumerWidget {
  const SuperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final localeCode = ref.watch(settingsProvider.select((s) => s.localeCode));
    // It lives for the life of the app rather than of a screen: a network
    // change must be caught wherever the user is, including when the app
    // was in the background and comes back.
    ref.watch(autoSwitchProvider);

    return MaterialApp.router(
      title: 'MeTube Super',
      debugShowCheckedModeBanner: false,
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      darkTheme: mtTheme(MTVariant.superApp, Brightness.dark),
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
