import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_hub.dart';
import 'package:metube_super/features/settings/settings_screen.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/settings/widgets/server_fields.dart';
import 'package:metube_super/features/settings/widgets/settings_fields.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Settings in two panes on a tablet held sideways** (approved mock-up,
/// 2026-10-10). A phone keeps the one long page, built from the same
/// sections in the same order.
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
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: const SettingsScreen(),
      ),
    );
  }

  Future<void> at(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  testWidgets('a phone keeps the long page', (tester) async {
    await at(tester, const Size(411, 914));
    expect(find.byType(SettingsHub), findsNothing);
    expect(find.byType(ServerFields), findsOneWidget);
  });

  testWidgets('a tablet upright keeps the long page too', (tester) async {
    await at(tester, const Size(800, 1280));
    expect(find.byType(SettingsHub), findsNothing);
  });

  testWidgets('a tablet on its side opens the server pane beside the list', (
    tester,
  ) async {
    await at(tester, const Size(1280, 800));
    expect(find.byType(SettingsHub), findsOneWidget);
    expect(find.byType(ServerFields), findsOneWidget);
    expect(find.byType(PreferencesFields), findsNothing);
    final l10n = tester.element(find.byType(SettingsHub)).mtl;

    await tester.tap(find.text(l10n.preferences));
    await tester.pumpAndSettle();
    expect(find.byType(PreferencesFields), findsOneWidget);
    expect(find.byType(ServerFields), findsNothing);

    await tester.tap(find.text(l10n.appearanceAndLanguage));
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceFields), findsOneWidget);
  });

  testWidgets('**device matrix**: neither shape overflows', (tester) async {
    await expectNoOverflow(tester, host);
  });
}
