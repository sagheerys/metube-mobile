/// **Every language named in itself**, never translated.
///
/// The language picker shows "العربية" and "English" the way their own
/// speakers write them, so someone who cannot read the current interface
/// language can still find theirs. That is why these names **stay out of
/// the arb files**: translating them into every other language costs
/// translators effort and helps nobody.
///
/// **Adding a language later is two lines**: an `app_xx.arb` file and one
/// line here. Forget the line and the language code shows instead of the
/// name. Nothing crashes, and `arb_parity_test` catches it.
const Map<String, String> mtLanguageNames = {'ar': 'العربية', 'en': 'English'};

/// The language name, or its code if it has not been registered yet.
String mtLanguageName(String code) => mtLanguageNames[code] ?? code;
