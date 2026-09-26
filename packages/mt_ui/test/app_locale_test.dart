import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **A notification speaks the app's language** (found 2026-09-26 while
/// taking the subscriptions screenshots: an English app on an English
/// phone posted its arrivals notice in Arabic).
void main() {
  const phones = <String, List<Locale>>{
    'English phone': [Locale('en', 'US')],
    'Arabic phone': [Locale('ar', 'SA')],
    'French first, English second': [Locale('fr', 'FR'), Locale('en', 'GB')],
    'a language the app lacks': [Locale('de', 'DE')],
  };

  for (final MapEntry(key: phone, value: locales) in phones.entries) {
    testWidgets('$phone on "system": the notice matches the screen', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = locales;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      late Locale shown;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              shown = Localizations.localeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        mtLocalizationsFor(null, systemLocales: locales).localeName,
        lookupMTLocalizations(shown).localeName,
      );
    });
  }

  test('an English phone gets English, not the old Arabic fallback', () {
    final l10n = mtLocalizationsFor(
      null,
      systemLocales: const [Locale('en', 'US')],
    );
    expect(l10n.localeName, 'en');
  });

  test('a language chosen in the app wins over the phone', () {
    final l10n = mtLocalizationsFor(
      'ar',
      systemLocales: const [Locale('en', 'US')],
    );
    expect(l10n.localeName, 'ar');
  });
}
