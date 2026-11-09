import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/settings/settings_page.dart';
import 'package:metube_lite/features/settings/settings_sections.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:metube_lite/features/shared/error_text.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// The optional Cloudflare Access service token in Settings → Server.
///
/// Guarded: a group that adds two mandatory-looking fields for everyone, a
/// stored pair that is not shown again, half a pair that gets saved, a pair
/// that is stored but never reaches the server config.
void main() {
  late ProviderContainer container;
  late MemorySecretStore secrets;

  final pair = CloudflareAccess(clientId: 'id.access', clientSecret: 's3cr3t');
  final stored = LiteSettings(
    serverUrl: 'https://metube.example.com',
    cloudflareAccess: pair,
  );

  ProviderContainer make([LiteSettings settings = const LiteSettings()]) {
    secrets = MemorySecretStore();
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(secrets),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(settings),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_cf_lite.log'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget host({
    String language = 'en',
    Brightness brightness = Brightness.light,
    LiteSettings settings = const LiteSettings(),
  }) => UncontrolledProviderScope(
    container: make(settings),
    child: MaterialApp(
      locale: Locale(language),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      theme: mtTheme(MTVariant.lite, brightness),
      home: const SettingsPage(SettingsPane.server),
    ),
  );

  MTLocalizations l10nOf(WidgetTester tester) =>
      MTLocalizations.of(tester.element(find.byType(SettingsPage)));

  testWidgets('folded for everyone without a pair, one tap opens it', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);
    expect(find.text(l10n.cloudflareAccess), findsOneWidget);
    expect(find.text(l10n.cloudflareClientId), findsNothing);

    await tester.ensureVisible(find.text(l10n.cloudflareAccess));
    await tester.tap(find.text(l10n.cloudflareAccess));
    await tester.pumpAndSettle();
    expect(find.text(l10n.cloudflareClientId), findsOneWidget);
    expect(find.text(l10n.cloudflareAccessHelp), findsOneWidget);
  });

  testWidgets('a stored pair opens the group, the secret masked', (
    tester,
  ) async {
    await tester.pumpWidget(host(settings: stored));
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);
    expect(find.text('id.access'), findsOneWidget);
    TextField secret() => tester.widget<TextField>(
      find.widgetWithText(TextField, l10n.cloudflareClientSecret),
    );
    expect(secret().obscureText, isTrue);

    await tester.ensureVisible(find.byTooltip(l10n.cloudflareShowSecret));
    await tester.tap(find.byTooltip(l10n.cloudflareShowSecret));
    await tester.pump();
    expect(secret().obscureText, isFalse);
    expect(find.byTooltip(l10n.cloudflareHideSecret), findsOneWidget);
  });

  testWidgets('one value alone is refused and nothing is stored', (
    tester,
  ) async {
    // Tall enough that the save button is not under the snack bar's room.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final l10n = l10nOf(tester);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.serverUrl),
      'https://metube.example.com',
    );
    await tester.ensureVisible(find.text(l10n.cloudflareAccess));
    await tester.tap(find.text(l10n.cloudflareAccess));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, l10n.cloudflareClientId),
      'id.access',
    );
    await tester.ensureVisible(find.text(l10n.saveSettings));
    await tester.tap(find.text(l10n.saveSettings));
    await tester.pump();

    expect(find.text(l10n.cloudflareBothRequired), findsOneWidget);
    expect(find.text(l10n.testingConnection), findsNothing);
    expect(await secrets.read(SecretKeys.cfAccessClientId), isNull);
    expect(container.read(settingsProvider).serverUrl, isEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  for (final language in ['en', 'ar']) {
    for (final brightness in Brightness.values) {
      testWidgets('**device matrix**: the open group overflows nothing '
          '($language, ${brightness.name})', (tester) async {
        await expectNoOverflow(
          tester,
          () => host(
            language: language,
            brightness: brightness,
            settings: stored,
          ),
        );
      });
    }
  }

  test('a stored pair loads into the server config, https only', () async {
    final store = MemoryKeyValueStore();
    final secrets = MemorySecretStore();
    await store.setString('server_url', 'https://metube.example.com');
    await CloudflareAccess.save(secrets, pair);
    final settings = await LiteSettings.load(store, secrets);
    expect(settings.cloudflareAccess, pair);
    expect(settings.serverConfig!.accessHeaders, {
      CloudflareAccess.idHeader: 'id.access',
      CloudflareAccess.secretHeader: 's3cr3t',
    });
    // The home address is cleartext and never behind Cloudflare.
    expect(
      settings
          .copyWith(serverUrl: 'http://192.168.1.10:8081')
          .serverConfig!
          .accessHeaders,
      isEmpty,
    );
  });

  test('a refused token has its own message, not the password one', () async {
    for (final code in ['en', 'ar']) {
      final l10n = await MTLocalizations.delegate.load(Locale(code));
      expect(
        errorText(l10n, const AccessRejectedException()),
        l10n.errAccessRejected,
      );
      expect(l10n.errAccessRejected, isNot(l10n.errAuth));
    }
  });
}
