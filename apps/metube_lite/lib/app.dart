import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import 'di.dart';
import 'router.dart';

/// جذر MeTube Lite: ثيم «وهج» بلون الفعل الخليجي البترولي + الترجمة
/// + الراوتر (الهوية واحدة والاختلاف وظيفي فقط — `01-PRD.md` §1.4).
class LiteApp extends ConsumerWidget {
  const LiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final localeCode =
        ref.watch(settingsProvider.select((s) => s.localeCode));

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
    );
  }
}
