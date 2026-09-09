import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// **حارس م-50 (قرار المالك 2026-09-06): «اتبع لغة النظام» بابٌ يُفتح.**
///
/// `locale: null` في `app.dart` كان يتبع لغة الهاتف فعلاً، لكن أول لمسة
/// للمبدّل تثبّت لغةً **إلى الأبد**: لا خيار ثالث يعيد القيمة فارغة،
/// فالرجوع للتلقائي كان يحتاج حذف بيانات التطبيق — ومعها المكتبة
/// والمفضلة.
void main() {
  late MemoryKeyValueStore store;

  ProviderContainer makeContainer({String? initialLocale}) {
    store = MemoryKeyValueStore();
    return ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          LiteSettings(localeCode: initialLocale),
        ),
      ],
    );
  }

  test('اختيار لغة يثبّتها في الحالة والتخزين', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).setLocale('en');

    expect(container.read(settingsProvider).localeCode, 'en');
    expect(await store.getString('app_locale'), 'en');
  });

  test('«النظام» يمحو اللغة المحفوظة — حالةً وتخزيناً', () async {
    final container = makeContainer(initialLocale: 'en');
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setLocale('en');

    await notifier.setLocale(null);

    // **الحارس**: `copyWith` القديم كان `localeCode ?? this.localeCode`
    // فيبتلع الـnull ويُبقي 'en' — أي أن الخيار الثالث يبدو أنه يعمل
    // ولا يعمل. و`clearLocale` هو ما يميّز «امسح» عن «لا تغيّر».
    expect(
      container.read(settingsProvider).localeCode,
      isNull,
      reason: 'فارغ ⇒ MaterialApp يمرّر locale: null فيتبع الهاتف',
    );
    expect(
      await store.getString('app_locale'),
      isNull,
      reason: 'ولا يعود بعد إعادة التشغيل',
    );
  });

  test('التحميل من تخزين بلا مفتاح لغة ⇒ اتباع النظام', () async {
    final settings = await LiteSettings.load(
      MemoryKeyValueStore(),
      MemorySecretStore(),
    );
    expect(settings.localeCode, isNull);
  });

  /// **الخطر الحقيقي في هذا التعديل ليس المنطق بل العرض**: شريحة ثالثة
  /// في زرّ مقسّم على شاشة 360dp قد تفيض — والفيض في وضع الإصدار
  /// شريطٌ أصفر لا يظهر، بل نصٌّ مقصوص.
  testWidgets('المبدّل الثلاثي يسع شاشة ضيقة بالعربية', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3; // 360dp عرضاً
    addTearDown(tester.view.reset);

    final container = makeContainer(initialLocale: 'ar');
    addTearDown(container.dispose);
    final l10n = await MTLocalizations.delegate.load(const Locale('ar'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(MTVariant.lite, Brightness.light),
          home: Scaffold(
            body: Center(
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'system',
                    label: Text(l10n.languageSystem),
                  ),
                  ButtonSegment(value: 'ar', label: Text(l10n.languageArabic)),
                  ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
                ],
                selected: const {'ar'},
                onSelectionChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.languageSystem), findsOneWidget);
    expect(find.text(l10n.languageArabic), findsOneWidget);
    expect(find.text(l10n.languageEnglish), findsOneWidget);
  });
}
