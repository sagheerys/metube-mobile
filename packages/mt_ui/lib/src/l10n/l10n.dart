import 'package:flutter/widgets.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'generated/mt_localizations.dart';

export 'generated/mt_localizations.dart';

/// تهيئة الترجمة الزمنية النسبية — عربي مسجل (خطوة 3.4).
void initMTL10n() {
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  timeago.setLocaleMessages('ar_short', timeago.ArShortMessages());
}

/// وصول مختصر: `context.mtl.libraryTitle`.
extension MTL10nX on BuildContext {
  MTLocalizations get mtl => MTLocalizations.of(this);
}

/// تاريخ نسبي بلغة السياق الحالية.
String mtTimeAgo(BuildContext context, DateTime time) =>
    timeago.format(time, locale: Localizations.localeOf(context).languageCode);
