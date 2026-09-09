import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The "follow the system language" guard (decision 2026-09-06): a door
/// that opens.**
///
/// `locale: null` in `app.dart` did follow the phone's language, but the
/// first touch of the switch pinned a language **forever**: there was no
/// third option to set the value back to empty, so returning to automatic
/// required clearing the app's data, and with it the library and the
/// favourites.
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
          SuperSettings(localeCode: initialLocale),
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

    // **The guard**: the old `copyWith` was `localeCode ??
    // this.localeCode`, which swallowed the null and kept 'en', so the
    // third option looked as though it worked and did not. `clearLocale` is
    // what distinguishes "clear" from "do not change".
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
    final settings = await SuperSettings.load(
      MemoryKeyValueStore(),
      MemorySecretStore(),
    );
    expect(settings.localeCode, isNull);
  });

  /// **The real risk in this change is presentation, not logic**: a third
  /// segment in a divided button on a 360dp screen may overflow, and an
  /// overflow in release mode is not a yellow stripe, which does not
  /// appear, but truncated text.
  testWidgets('المبدّل الثلاثي يسع شاشة ضيقة بالعربية', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3; // 360dp wide
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
          theme: mtTheme(MTVariant.superApp, Brightness.light),
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
