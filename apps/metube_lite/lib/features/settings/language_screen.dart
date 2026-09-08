import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';

/// **شاشة اختيار اللغة** (طلب المالك 2026-09-08).
///
/// كان الاختيار زرّاً مقسّماً بثلاث شرائح. و`SegmentedButton` يقسم العرض
/// على عدد الخيارات: ثلاثةٌ تسع شاشة 360dp، **وستةٌ تنكسر** — والخطة
/// المعلنة دعم اللغات الشائعة. القائمة تتمدّد بلا حدّ وبلا كسر.
///
/// «اتبع النظام» أولاً وبلا رمز لغة: هو **غياب اختيار** لا لغةً بعينها
/// (م-50). واللغات تُقرأ من [MTLocalizations.supportedLocales] لا من
/// قائمة مكتوبة بيد — فإضافة `app_xx.arb` تُظهر لغتها هنا تلقائياً.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final selected = ref.watch(settingsProvider).localeCode;
    final notifier = ref.read(settingsProvider.notifier);

    Widget tile({
      required String title,
      required bool checked,
      required VoidCallback onTap,
      String? subtitle,
    }) =>
        ListTile(
          title: Text(title),
          subtitle: subtitle == null
              ? null
              : Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          trailing: checked
              ? Icon(Icons.check_rounded, color: p.accentInk)
              : null,
          onTap: onTap,
        );

    final codes = [
      for (final locale in MTLocalizations.supportedLocales)
        locale.languageCode,
    ]..sort();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.language)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: MTSpace.xxl),
        children: [
          tile(
            title: l10n.languageSystem,
            subtitle: l10n.languageSystemHint,
            checked: selected == null,
            onTap: () => notifier.setLocale(null),
          ),
          const Divider(height: 1),
          for (final code in codes)
            tile(
              title: mtLanguageName(code),
              checked: selected == code,
              onTap: () => notifier.setLocale(code),
            ),
        ],
      ),
    );
  }
}
