import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/features/shared/error_text.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Lite keeps deferring to the server's owner, on purpose** (2026-09-20).
///
/// Super's copy of this message now names its own Cookies screen. Lite has no
/// such screen and is not going to get one: it is the family's app, and the
/// person holding it is usually not the person who runs the server. Telling
/// them to upload a cookies file would send them looking for a button that
/// does not exist — so the divergence between the two apps is deliberate,
/// and this test is what keeps it deliberate rather than forgotten.
void main() {
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    test('in ${locale.languageCode} it points at whoever runs the server', () {
      final l10n = lookupMTLocalizations(locale);
      final text = errorText(l10n, const PlatformBlockedException('...'));

      expect(text, l10n.errPlatformBlocked);
      expect(
        text,
        isNot(contains(l10n.cookiesUpload)),
        reason: 'لا شاشة كوكيز في Lite، فلا تُوجّه إليها',
      );
    });
  }
}
