import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/addresses_data.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/data/setup_data.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/features/setup/setup_dialog.dart';
import 'package:metube_desktop/shell/error_text.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'desktop_matrix.dart';
import 'support/shell_harness.dart';

/// The optional Cloudflare Access service token in Ember's server setup.
///
/// Guarded: two new fields shown to everyone, half a pair that is kept, a
/// pair that is tested but never stored, stored in the settings file
/// instead of the secret store, or dropped when another address is chosen.
void main() {
  const tunnel = 'https://metube.example.com';
  final pair = CloudflareAccess(clientId: 'id.access', clientSecret: 's3cr3t');

  Future<List<ServerConfig>> open(WidgetTester tester) async {
    final tested = <ServerConfig>[];
    ShellHarness.useWindow(tester, const Size(1440, 900));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, Object?>{'text': ''}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final h = ShellHarness(
      library: const [],
      overrides: [
        connectionTestProvider.overrideWithValue((config) async {
          tested.add(config);
        }),
      ],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    return tested;
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(EmberSidebar)));

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> unfold(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Cloudflare Access (optional)'));
    await tester.tap(find.text('Cloudflare Access (optional)'));
    await tester.pumpAndSettle();
  }

  testWidgets('folded for everyone, one click opens it', (tester) async {
    await open(tester);
    expect(field('Client ID'), findsNothing);
    await unfold(tester);
    expect(field('Client ID'), findsOneWidget);
    expect(field('Client Secret'), findsOneWidget);
  });

  testWidgets('one value alone is refused before any test, nothing kept', (
    tester,
  ) async {
    final tested = await open(tester);
    await tester.enterText(field('Server URL (MeTube)'), tunnel);
    await unfold(tester);
    await tester.enterText(field('Client ID'), 'id.access');
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Enter both the Client ID and the Client Secret, or leave both empty',
      ),
      findsOneWidget,
    );
    expect(tested, isEmpty);
    expect(container(tester).read(serverSetupProvider), isNull);
  });

  testWidgets('a full pair is tested, kept in the secret store alone, and '
      'travels to every address', (tester) async {
    final tested = await open(tester);
    await tester.enterText(field('Server URL (MeTube)'), tunnel);
    await unfold(tester);
    await tester.enterText(field('Client ID'), ' id.access ');
    await tester.enterText(field('Client Secret'), 's3cr3t');
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();

    expect(tested.single.access, pair);
    expect(tested.single.accessHeaders, hasLength(2));
    final c = container(tester);
    final secrets = c.read(secretStoreProvider);
    expect(await secrets.read(SecretKeys.cfAccessClientId), 'id.access');
    expect(await secrets.read(SecretKeys.cfAccessClientSecret), 's3cr3t');
    final store = c.read(keyValueStoreProvider);
    for (final key in await store.keys()) {
      expect('${await store.get(key)}', isNot(contains('s3cr3t')));
    }
    expect(c.read(serverSetupProvider)!.access, pair);
  });

  test('the pair travels to whichever address is chosen', () async {
    // The shell harness replaces the server config, so this one is real.
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        initialServerSetupProvider.overrideWithValue(
          ServerConfig(baseUrl: tunnel, username: 'me', access: pair),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(serverConfigProvider)!.accessHeaders, hasLength(2));

    await c.read(addressesProvider.notifier).use('http://192.168.1.10:8081');
    final home = c.read(serverConfigProvider)!;
    expect(home.baseUrl, 'http://192.168.1.10:8081');
    expect((home.username, home.access), ('me', pair));
    // Cleartext: https alone decides, whatever is stored.
    expect(home.accessHeaders, isEmpty);
  });

  test('the setup store reads the pair back and clears it', () async {
    final store = ServerSetupStore(
      store: MemoryKeyValueStore(),
      secrets: MemorySecretStore(),
      mutex: PrefsMutex(),
    );
    await store.write(ServerConfig(baseUrl: tunnel, access: pair));
    expect((await store.read())!.access, pair);
    await store.write(ServerConfig(baseUrl: tunnel));
    expect((await store.read())!.access, isNull);
  });

  test('a refused token has its own message', () async {
    final l = await MTLocalizations.delegate.load(const Locale('en'));
    expect(errorText(l, const AccessRejectedException()), l.errAccessRejected);
  });

  testWidgets('the setup with the group open overflows nothing', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      () => ShellHarness(library: const []).app(),
      then: (tester) async {
        unawaited(showSetupDialog(tester.element(find.byType(EmberSidebar))));
        await tester.pumpAndSettle();
        // The dialog scrolls in a small window: bring the link into view.
        final link = find.byKey(const ValueKey('cloudflare-access'));
        await tester.ensureVisible(link);
        await tester.pumpAndSettle();
        await tester.tap(link);
      },
    );
  });
}
