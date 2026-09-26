import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'generated/mt_localizations.dart';

/// **The texts for a notification, in the language the app shows.**
///
/// A notification is built outside the widget tree, so it cannot ask the
/// tree which language won. It used to fall back to Arabic whenever the
/// user had left the language on "system", so an English phone got an
/// English app and Arabic notifications.
///
/// [localeCode] is the user's explicit choice, or null for "system". The
/// system case runs the resolution `MaterialApp` itself runs, over the
/// phone's preferred languages, so the two cannot disagree.
MTLocalizations mtLocalizationsFor(
  String? localeCode, {
  List<Locale>? systemLocales,
}) {
  final locale = localeCode != null
      ? Locale(localeCode)
      : basicLocaleListResolution(
          systemLocales ?? PlatformDispatcher.instance.locales,
          MTLocalizations.supportedLocales,
        );
  return lookupMTLocalizations(locale);
}
