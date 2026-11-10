import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/network_screen.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/settings/widgets/server_fields.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// A password typed with an `http://` address on the internet travels in
/// the clear. The computer warned about it from the start; the phones said
/// nothing (security review 2026-11-05).
void main() {
  const warning =
      'An http:// address outside your home network sends the password '
      'unencrypted. From outside, use an https:// address.';

  Widget host(Widget body, {SuperSettings settings = const SuperSettings()}) =>
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(settings),
          loggerProvider.overrideWithValue(
            MTLogger(filePath: '${Directory.systemTemp.path}/mtf_plain.log'),
          ),
          endpointsStatusProvider.overrideWith((ref) async => const {}),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: body is NetworkScreen
              ? body
              : Scaffold(body: SingleChildScrollView(child: body)),
        ),
      );

  Future<void> type(WidgetTester tester, String url, String password) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), url);
    await tester.enterText(fields.at(2), password);
    await tester.pump();
  }

  testWidgets('the server fields warn as an internet http address is typed '
      'with a password', (tester) async {
    await tester.pumpWidget(host(const ServerFields()));
    await type(tester, 'http://my-nas.duckdns.org:8081', 'secret');
    expect(find.text(warning), findsOneWidget);

    await type(tester, 'https://my-nas.duckdns.org', 'secret');
    expect(find.text(warning), findsNothing);
    await type(tester, 'http://192.168.1.20:8081', 'secret');
    expect(find.text(warning), findsNothing);
    await type(tester, 'http://my-nas.duckdns.org:8081', '');
    expect(find.text(warning), findsNothing);
  });

  testWidgets('the network page marks an extra address that would send the '
      'password in the clear, and only that one', (tester) async {
    await tester.pumpWidget(
      host(
        const NetworkScreen(),
        settings: const SuperSettings(
          password: 'secret',
          localUrl: 'http://192.168.1.20:8081',
          externalUrls: [
            'http://my-nas.duckdns.org:8081',
            'https://metube.example.com',
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(warning), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plain-http-http://my-nas.duckdns.org:8081')),
      findsOneWidget,
    );
  });

  testWidgets('without a password there is nothing to warn about', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const NetworkScreen(),
        settings: const SuperSettings(
          externalUrls: ['http://my-nas.duckdns.org:8081'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(warning), findsNothing);
  });

  testWidgets('the warning fits every device and text size', (tester) async {
    await expectNoOverflow(
      tester,
      () => host(
        const NetworkScreen(),
        settings: const SuperSettings(
          password: 'secret',
          externalUrls: ['http://my-nas.duckdns.org:8081'],
        ),
      ),
    );
  });
}
