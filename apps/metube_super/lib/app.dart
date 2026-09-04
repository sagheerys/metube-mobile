import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import 'di.dart';
import 'features/settings/auto_switch.dart';
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
    // م-28: يعيش بعمر التطبيق لا بعمر شاشة — تغيّر الشبكة يجب أن
    // يُلتقط والمستخدم في أي مكان (وحتى والتطبيق بالخلفية ثم يعود).
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
      // **أشرطة النظام تتبع الثيم** — بلا حجاب التباين الذي يفرضه
      // أندرويد خلف أزرار التنقل الثلاثة فيقطع لون الشريط السفلي.
      builder: (context, child) =>
          MTSystemBars(child: child ?? const SizedBox.shrink()),
    );
  }
}
