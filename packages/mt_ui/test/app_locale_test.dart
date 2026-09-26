import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Which language a phone gets, on screen and in notifications.**
///
/// Found 2026-09-26 while taking the subscriptions screenshots: an English
/// app on an English phone posted its arrivals notice in Arabic. Checking
/// that showed the second fault: a phone in a language the app lacks got
/// the whole app in Arabic, Flutter's fallback being the first supported
/// language.
void main() {
  const phones = <String, (List<Locale>, String)>{
    'English phone': ([Locale('en', 'US')], 'en'),
    'Arabic phone': ([Locale('ar', 'SA')], 'ar'),
    'French first, Arabic second': (
      [Locale('fr', 'FR'), Locale('ar', 'EG')],
      'ar',
    ),
    'German only': ([Locale('de', 'DE')], 'en'),
    'French and German': ([Locale('fr', 'FR'), Locale('de', 'DE')], 'en'),
  };

  for (final MapEntry(key: phone, value: (locales, expected))
      in phones.entries) {
    testWidgets('$phone on "system": the screen and the notice both get '
        '"$expected"', (tester) async {
      tester.platformDispatcher.localesTestValue = locales;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      late Locale shown;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          localeListResolutionCallback: mtLocaleResolution,
          home: Builder(
            builder: (context) {
              shown = Localizations.localeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(shown.languageCode, expected);
      expect(
        mtLocalizationsFor(null, systemLocales: locales).localeName,
        expected,
      );
    });
  }

  test('a language chosen in the app wins over the phone', () {
    final l10n = mtLocalizationsFor(
      'ar',
      systemLocales: const [Locale('en', 'US')],
    );
    expect(l10n.localeName, 'ar');
  });
}
