import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'generated/mt_localizations.dart';

/// **Which of the app's languages a phone gets**, for `MaterialApp`'s
/// `localeListResolutionCallback` and for [mtLocalizationsFor] alike.
///
/// Flutter's own resolution falls back to the first supported language,
/// which is Arabic here, so a phone in German or French showed the whole
/// app in Arabic. A phone that speaks none of the app's languages now gets
/// English, the one most such readers can follow; a phone that lists one
/// of them anywhere in its preferences still gets that one, as before.
Locale mtLocaleResolution(List<Locale>? preferred, Iterable<Locale> supported) {
  final languages = {for (final locale in supported) locale.languageCode};
  final speaksOne = (preferred ?? const <Locale>[]).any(
    (locale) => languages.contains(locale.languageCode),
  );
  if (!speaksOne) return const Locale('en');
  return basicLocaleListResolution(preferred, supported);
}

/// **The texts for a notification, in the language the app shows.**
///
/// A notification is built outside the widget tree, so it cannot ask the
/// tree which language won. It used to fall back to Arabic whenever the
/// user had left the language on "system", so an English phone got an
/// English app and Arabic notifications.
///
/// [localeCode] is the user's explicit choice, or null for "system". The
/// system case runs [mtLocaleResolution], the same rule the screens use,
/// so the two cannot disagree.
MTLocalizations mtLocalizationsFor(
  String? localeCode, {
  List<Locale>? systemLocales,
}) {
  final locale = localeCode != null
      ? Locale(localeCode)
      : mtLocaleResolution(
          systemLocales ?? PlatformDispatcher.instance.locales,
          MTLocalizations.supportedLocales,
        );
  return lookupMTLocalizations(locale);
}
