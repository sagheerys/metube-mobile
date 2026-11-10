import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:metube_lite/features/settings/widgets/server_fields.dart';
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

  Widget host({String language = 'en'}) => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      initialSettingsProvider.overrideWithValue(const LiteSettings()),
      loggerProvider.overrideWithValue(
        MTLogger(filePath: '${Directory.systemTemp.path}/mtf_plain.log'),
      ),
    ],
    child: MaterialApp(
      locale: Locale(language),
      theme: mtTheme(MTVariant.lite, Brightness.light),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: const Scaffold(body: SingleChildScrollView(child: ServerFields())),
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
    await tester.pumpWidget(host());
    await type(tester, 'http://my-nas.duckdns.org:8081', 'secret');
    expect(find.text(warning), findsOneWidget);

    await type(tester, 'https://my-nas.duckdns.org', 'secret');
    expect(find.text(warning), findsNothing);
    await type(tester, 'http://192.168.1.20:8081', 'secret');
    expect(find.text(warning), findsNothing);
    await type(tester, 'http://my-nas.duckdns.org:8081', '');
    expect(find.text(warning), findsNothing);
  });

  testWidgets('the warning fits every device, in both languages', (
    tester,
  ) async {
    for (final language in ['en', 'ar']) {
      await expectNoOverflow(tester, () => host(language: language));
    }
    await tester.pumpWidget(host(language: 'ar'));
    await type(tester, 'http://my-nas.duckdns.org:8081', 'secret');
    expect(find.byKey(const ValueKey('plain-http-warning')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
