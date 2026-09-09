import 'package:flutter/widgets.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'generated/mt_localizations.dart';

export 'generated/mt_localizations.dart';

/// Registers the relative-time locales; Arabic is registered explicitly.
void initMTL10n() {
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  timeago.setLocaleMessages('ar_short', timeago.ArShortMessages());
}

/// Shorthand access: `context.mtl.libraryTitle`.
extension MTL10nX on BuildContext {
  MTLocalizations get mtl => MTLocalizations.of(this);
}

/// A relative date in the locale currently in context.
String mtTimeAgo(BuildContext context, DateTime time) =>
    timeago.format(time, locale: Localizations.localeOf(context).languageCode);
