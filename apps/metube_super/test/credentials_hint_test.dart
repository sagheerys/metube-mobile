import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_screen.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Field report 2026-09-19:** "in the username and password fields the
/// user has to press the question mark to learn whether the field is
/// optional — someone whose server is open assumes both are mandatory".
///
/// The sentence existed all along (`authHelper`) and was shown only to
/// whoever thought to press "?", which is exactly the person who did not
/// need it. It is now under the field, and these guard both halves: that
/// it is readable without any tap, and that the extra line it costs does
/// not push the screen off a small phone at a large font.
void main() {
  Widget host() {
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
      ],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: const SettingsScreen(),
      ),
    );
  }

  testWidgets('the credentials are visibly optional, with no tap', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final l10n = MTLocalizations.of(
      tester.element(find.byType(SettingsScreen)),
    );
    expect(
      find.text(l10n.authHelper),
      findsOneWidget,
      reason: 'it used to take pressing "?" to find this out',
    );
  });

  testWidgets('**device matrix**: the added line overflows nothing', (
    tester,
  ) async {
    await expectNoOverflow(tester, host);
  });
}
