import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/language_screen.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// **طلب المالك 2026-09-08**: الاختيار كان `SegmentedButton` بثلاث
/// شرائح، وهو يقسم العرض على عددها — فثلاثةٌ تسع 360dp **وستةٌ تنكسر**،
/// والخطة المعلنة دعم اللغات الشائعة.
void main() {
  ProviderContainer containerWith(String? locale, MemoryKeyValueStore store) =>
      ProviderContainer(overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider
            .overrideWithValue(SuperSettings(localeCode: locale)),
      ]);

  Future<ProviderContainer> pump(WidgetTester tester, String? locale) async {
    final store = MemoryKeyValueStore();
    final container = containerWith(locale, store);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: const LanguageScreen(),
      ),
    ));
    await tester.pump();
    return container;
  }

  testWidgets('كل لغة مدعومة لها صف، و«النظام» فوقها', (tester) async {
    await pump(tester, null);

    // **الحارس الحقيقي**: القائمة تُقرأ من `supportedLocales` لا من
    // ثلاث شرائح مكتوبة بيد — فإضافة `app_xx.arb` تظهر تلقائياً.
    for (final locale in MTLocalizations.supportedLocales) {
      expect(find.text(mtLanguageName(locale.languageCode)), findsOneWidget,
          reason: locale.languageCode);
    }
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('العلامة على «النظام» حين لا لغة محفوظة', (tester) async {
    await pump(tester, null);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('اختيار لغة يحفظها، والعلامة تنتقل إليها', (tester) async {
    final container = await pump(tester, null);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).localeCode, 'en');
    expect(find.byIcon(Icons.check_rounded), findsOneWidget,
        reason: 'علامة واحدة لا اثنتان');
  });

  testWidgets('العودة إلى «النظام» تمحو اللغة (م-50)', (tester) async {
    final container = await pump(tester, 'en');
    expect(container.read(settingsProvider).localeCode, 'en');

    await tester.tap(find.text('النظام'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).localeCode, isNull);
  });

  /// الشاشة الضيقة هي سبب وجود هذه الشاشة أصلاً.
  testWidgets('عشر لغات لا تكسر شاشة 360dp', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pump(tester, null);
    expect(tester.takeException(), isNull);
  });
}
