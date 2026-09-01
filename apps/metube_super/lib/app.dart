import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import 'di.dart';
import 'router.dart';

/// جذر MeTube Super: ثيم «وهج» بهوية Super + الترجمة + الراوتر.
class SuperApp extends ConsumerWidget {
  const SuperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(settingsProvider.select((s) => s.themeMode));
    final localeCode =
        ref.watch(settingsProvider.select((s) => s.localeCode));

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
    );
  }
}
