import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/settings/language_screen.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Requested 2026-09-08**: the choice was a `SegmentedButton` with three
/// segments, and it divides the width by their number, so three fit 360dp
/// **and six break**, while the declared plan is to support the common
/// languages.
void main() {
  ProviderContainer containerWith(String? locale, MemoryKeyValueStore store) =>
      ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(
            LiteSettings(localeCode: locale),
          ),
        ],
      );

  Future<ProviderContainer> pump(WidgetTester tester, String? locale) async {
    final store = MemoryKeyValueStore();
    final container = containerWith(locale, store);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(MTVariant.lite, Brightness.light),
          home: const LanguageScreen(),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('every supported language has a row, with System above them', (
    tester,
  ) async {
    await pump(tester, null);

    // **The real guard**: the list is read from `supportedLocales` rather
    // than from three hand-written segments, so adding an `app_xx.arb`
    // appears automatically.
    for (final locale in MTLocalizations.supportedLocales) {
      expect(
        find.text(mtLanguageName(locale.languageCode)),
        findsOneWidget,
        reason: locale.languageCode,
      );
    }
    expect(find.text('العربية'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('the tick sits on System when no language is saved', (
    tester,
  ) async {
    await pump(tester, null);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('choosing a language saves it, and the tick moves to it', (
    tester,
  ) async {
    final container = await pump(tester, null);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).localeCode, 'en');
    expect(
      find.byIcon(Icons.check_rounded),
      findsOneWidget,
      reason: 'علامة واحدة لا اثنتان',
    );
  });

  testWidgets('going back to System clears the saved language', (tester) async {
    final container = await pump(tester, 'en');
    expect(container.read(settingsProvider).localeCode, 'en');

    await tester.tap(find.text('النظام'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).localeCode, isNull);
  });

  /// A narrow screen is the whole reason this screen exists.
  testWidgets('ten languages do not break a 360dp screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pump(tester, null);
    expect(tester.takeException(), isNull);
  });

  testWidgets('**device matrix**: the language screen does not overflow', (
    tester,
  ) async {
    final store = MemoryKeyValueStore();
    final container = containerWith(null, store);
    addTearDown(container.dispose);
    await expectNoOverflow(
      tester,
      () => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(MTVariant.lite, Brightness.light),
          home: const LanguageScreen(),
        ),
      ),
    );
  });
}
