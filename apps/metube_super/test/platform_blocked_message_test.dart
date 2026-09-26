import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/shared/error_text.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// **What a platform that wants a login tells the Super user**
/// (2026-09-20).
///
/// Vimeo answers `The web client only works when logged-in. Use --cookies…`,
/// which the core classifies as [PlatformBlockedException]. The message the
/// user then reads used to defer to "the server admin" — and in Super the
/// reader *is* the admin, holding a screen that takes the file.
void main() {
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    test('in ${locale.languageCode} it names the screen that fixes it', () {
      final l10n = lookupMTLocalizations(locale);
      final text = errorText(l10n, const PlatformBlockedException('...'));

      expect(text, l10n.errPlatformBlockedCookies);
      expect(
        text,
        contains(l10n.cookies),
        reason: 'الرسالة تسمّي الشاشة نفسها، فلا يبحث عنها',
      );
      expect(
        text,
        isNot(contains(l10n.errPlatformBlocked)),
        reason: 'ولا تحيله إلى «مدير السيرفر» وهو المدير',
      );
    });
  }

  test('the real Vimeo error is what reaches it', () {
    // Copied from a real server, 2026-09-20.
    const vimeo =
        'ERROR: [vimeo] 1225400313: The web client only works when logged-in. '
        'Use --cookies, --cookies-from-browser, --username and --password, '
        '--netrc-cmd, or --netrc (vimeo) to provide account credentials.';
    expect(UrlKit.isPlatformBlockedError(vimeo), isTrue);

    final item = HistoryItem.fromJson(const {
      'url': 'https://vimeo.com/1225400313',
      'status': 'error',
      'error': vimeo,
    });
    expect(item.isPlatformBlocked, isTrue);
  });
}
