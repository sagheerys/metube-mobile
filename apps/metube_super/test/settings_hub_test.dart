import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_hub.dart';
import 'package:metube_super/features/settings/settings_page.dart';
import 'package:metube_super/features/settings/settings_screen.dart';
import 'package:metube_super/features/settings/settings_sections.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/settings/widgets/server_fields.dart';
import 'package:metube_super/features/settings/widgets/settings_fields.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **The settings home** (approved mock-up, 2026-10-14): three short
/// groups whose rows show each setting as it stands, each opening its own
/// page. On a tablet held sideways the same rows open in two panes
/// (approved 2026-10-10).
void main() {
  Widget host({SuperSettings settings = const SuperSettings()}) {
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(settings),
        // The logs and backup pages read the log on opening.
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_settings.log'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SettingsScreen(),
          routes: [
            for (final pane in SettingsPane.values)
              GoRoute(path: pane.name, builder: (_, _) => SettingsPage(pane)),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
      ),
    );
  }

  Future<void> at(
    WidgetTester tester,
    Size size, {
    SuperSettings settings = const SuperSettings(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(settings: settings));
    await tester.pumpAndSettle();
  }

  MTLocalizations l10nOf(WidgetTester tester) =>
      tester.element(find.byType(SettingsScreen)).mtl;

  testWidgets('a phone opens on the short home, not the long page', (
    tester,
  ) async {
    await at(tester, const Size(411, 914));
    expect(find.byType(SettingsHub), findsNothing);
    expect(find.byType(ServerFields), findsNothing);
    expect(find.byType(MTSettingsRow), findsWidgets);
  });

  testWidgets('a tablet upright keeps the phone\'s home too', (tester) async {
    await at(tester, const Size(800, 1280));
    expect(find.byType(SettingsHub), findsNothing);
    expect(find.byType(MTSettingsRow), findsWidgets);
  });

  testWidgets('GUARD: every section has a row, and its row opens its page', (
    tester,
  ) async {
    // Tall enough for the whole list, so no row is out of reach.
    await at(tester, const Size(411, 2000));
    final l10n = l10nOf(tester);
    final titles = {
      SettingsPane.server: l10n.serverConfiguration,
      SettingsPane.network: l10n.networkSettings,
      SettingsPane.subscriptions: l10n.subscriptions,
      SettingsPane.cookies: l10n.cookies,
      SettingsPane.downloads: l10n.settingsDownloads,
      SettingsPane.playback: l10n.settingsPlayback,
      SettingsPane.appearance: l10n.appearanceAndLanguage,
      SettingsPane.transcripts: l10n.settingsTranscripts,
      SettingsPane.backup: l10n.settingsBackup,
      SettingsPane.updates: l10n.updates,
      SettingsPane.logs: l10n.diagnosticLogs,
      SettingsPane.about: l10n.aboutApp,
    };
    expect(titles.keys, SettingsPane.values, reason: 'a section without a row');
    expect(
      find.byType(MTSettingsRow),
      findsNWidgets(SettingsPane.values.length),
    );

    for (final MapEntry(key: pane, value: title) in titles.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(MTSettingsRow),
          matching: find.text(title),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byWidgetPredicate((w) => w is SettingsPage && w.pane == pane),
        findsOneWidget,
        reason: '$pane',
      );
      GoRouter.of(tester.element(find.byType(SettingsPage))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  });

  testWidgets('each row shows the setting as it stands', (tester) async {
    await at(
      tester,
      const Size(411, 2000),
      settings: const SuperSettings(
        localUrl: 'http://nas.local:8081',
        activeUrl: 'http://nas.local:8081',
        externalUrls: ['https://tube.example.com'],
        username: 'yasir',
        quality: Quality.q720,
        wifiOnly: true,
        themeMode: ThemeMode.dark,
        compatiblePlayback: false,
      ),
    );
    final l10n = l10nOf(tester);
    expect(find.text(mtMetaLine(['nas.local:8081', 'yasir'])), findsOneWidget);
    expect(
      find.text(
        mtMetaLine([l10n.settingsValueAuto, l10n.settingsValueLocalNow]),
      ),
      findsOneWidget,
    );
    expect(
      find.text(mtMetaLine([l10n.quality720, l10n.settingsValueWifiOnly])),
      findsOneWidget,
    );
    expect(find.text(l10n.settingsValueCompatOff), findsOneWidget);
    expect(find.text(mtMetaLine([l10n.themeDark, 'English'])), findsOneWidget);
    expect(find.text(l10n.settingsValueOff), findsOneWidget);
  });

  testWidgets('a server not set up yet says so on its row', (tester) async {
    await at(tester, const Size(411, 914));
    expect(find.text(l10nOf(tester).settingsValueNotSet), findsOneWidget);
  });

  testWidgets('a tablet on its side opens the server pane beside the list', (
    tester,
  ) async {
    await at(tester, const Size(1280, 800));
    expect(find.byType(SettingsHub), findsOneWidget);
    expect(find.byType(ServerFields), findsOneWidget);
    expect(find.byType(DownloadFields), findsNothing);
    final l10n = l10nOf(tester);

    await tester.tap(find.text(l10n.settingsDownloads));
    await tester.pumpAndSettle();
    expect(find.byType(DownloadFields), findsOneWidget);
    expect(find.byType(ServerFields), findsNothing);

    await tester.tap(find.text(l10n.settingsPlayback));
    await tester.pumpAndSettle();
    expect(find.byType(PlaybackFields), findsOneWidget);

    await tester.tap(find.text(l10n.appearanceAndLanguage));
    await tester.pumpAndSettle();
    expect(find.byType(AppearanceFields), findsOneWidget);
  });

  testWidgets('the arrivals notice left the download settings', (tester) async {
    await at(tester, const Size(1280, 800));
    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.settingsDownloads));
    await tester.pumpAndSettle();
    expect(find.text(l10n.notifyArrivals), findsNothing);
  });

  testWidgets('**device matrix**: neither shape overflows', (tester) async {
    await expectNoOverflow(tester, host);
  });

  testWidgets('**device matrix**: nor does any section\'s own page', (
    tester,
  ) async {
    for (final pane in const [
      SettingsPane.server,
      SettingsPane.downloads,
      SettingsPane.playback,
      SettingsPane.appearance,
      SettingsPane.transcripts,
      SettingsPane.updates,
    ]) {
      await expectNoOverflow(tester, () {
        final app = host() as UncontrolledProviderScope;
        return UncontrolledProviderScope(
          container: app.container,
          child: MaterialApp(
            localizationsDelegates: MTLocalizations.localizationsDelegates,
            supportedLocales: MTLocalizations.supportedLocales,
            theme: mtTheme(MTVariant.superApp, Brightness.light),
            home: SettingsPage(pane),
          ),
        );
      });
    }
  });
}
