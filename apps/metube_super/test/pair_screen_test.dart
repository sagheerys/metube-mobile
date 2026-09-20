import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/pair_screen.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'device_matrix.dart';

/// **The setup code screen** (م-74).
///
/// It draws a password into a picture, so most of what matters here is
/// about *not* drawing it: not before it is asked for, and not still
/// showing the previous address after the choice changes.
void main() {
  ProviderContainer containerWith(SuperSettings settings) => ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      initialSettingsProvider.overrideWithValue(settings),
    ],
  );

  Widget host(
    ProviderContainer container, {
    Locale locale = const Locale('en'),
  }) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      locale: locale,
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: const PairScreen(),
    ),
  );

  Future<ProviderContainer> open(
    WidgetTester tester,
    SuperSettings settings, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 2200);
    addTearDown(tester.view.reset);
    final container = containerWith(settings);
    addTearDown(container.dispose);
    await tester.pumpWidget(host(container, locale: locale));
    await tester.pumpAndSettle();
    return container;
  }

  const withPassword = SuperSettings(
    localUrl: 'http://192.168.2.245:8086',
    externalUrls: ['https://mtube.example.com'],
    activeUrl: 'https://mtube.example.com',
    username: 'family',
    password: 'secret',
  );

  testWidgets(
    'the code is COVERED until it is asked for: it is a password in a '
    'picture, and a screen face up on a table should not be showing one',
    (tester) async {
      await open(tester, withPassword);

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Show the code'), findsOneWidget);

      await tester.tap(find.text('Show the code'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
    },
  );

  testWidgets('the drawn code is the one Lite can read back', (tester) async {
    await open(tester, withPassword);
    await tester.tap(find.text('Show the code'));
    await tester.pumpAndSettle();

    // The picture keeps its data private, so the address is read off the
    // widget's key and the contents off the builder the screen uses.
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.key, const ValueKey('https://mtube.example.com'));

    final decoded = PairingPayload.decode(
      pairingPayloadFor(withPassword, 'https://mtube.example.com').encode(),
    )!;
    expect(decoded.url, 'https://mtube.example.com');
    expect(decoded.username, 'family');
    expect(decoded.password, 'secret');
  });

  testWidgets(
    'changing the address hides the code again — showing the old one for '
    'even a frame would pair the phone to the wrong address',
    (tester) async {
      await open(tester, withPassword);
      await tester.tap(find.text('Show the code'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);

      await tester.tap(find.text('http://192.168.2.245:8086'));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Show the code'), findsOneWidget);
    },
  );

  testWidgets('and then it draws the newly chosen address', (tester) async {
    await open(tester, withPassword);
    await tester.tap(find.text('http://192.168.2.245:8086'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show the code'));
    await tester.pumpAndSettle();

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.key, const ValueKey('http://192.168.2.245:8086'));
  });

  testWidgets('a house address warns that their app stops at the front door', (
    tester,
  ) async {
    await open(
      tester,
      const SuperSettings(
        localUrl: 'http://192.168.2.245:8086',
        activeUrl: 'http://192.168.2.245:8086',
      ),
    );
    expect(find.textContaining('home address'), findsOneWidget);
  });

  testWidgets('a public address does not', (tester) async {
    await open(
      tester,
      const SuperSettings(
        externalUrls: ['https://mtube.example.com'],
        activeUrl: 'https://mtube.example.com',
      ),
    );
    expect(find.textContaining('home address'), findsNothing);
  });

  testWidgets(
    'the password warning is always there, and says the right thing for a '
    'server that has no password at all',
    (tester) async {
      await open(tester, withPassword);
      expect(
        find.textContaining('carries your server password'),
        findsOneWidget,
      );

      await open(
        tester,
        const SuperSettings(
          externalUrls: ['https://mtube.example.com'],
          activeUrl: 'https://mtube.example.com',
        ),
      );
      expect(find.textContaining('no password'), findsOneWidget);
    },
  );

  testWidgets('with no server there is nothing to hand over', (tester) async {
    await open(tester, const SuperSettings());
    expect(find.textContaining('nothing to hand over'), findsOneWidget);
    expect(find.text('Show the code'), findsNothing);
  });

  testWidgets('one address offers no choice of address', (tester) async {
    await open(
      tester,
      const SuperSettings(
        localUrl: 'http://192.168.2.245:8086',
        activeUrl: 'http://192.168.2.245:8086',
      ),
    );
    expect(find.byType(RadioListTile<String>), findsNothing);
  });

  testWidgets('the layout holds on every device and text scale', (
    tester,
  ) async {
    final container = containerWith(withPassword);
    addTearDown(container.dispose);
    await expectNoOverflow(tester, () => host(container));
  });

  testWidgets('and in Arabic', (tester) async {
    final container = containerWith(withPassword);
    addTearDown(container.dispose);
    await expectNoOverflow(
      tester,
      () => host(container, locale: const Locale('ar')),
    );
  });
}
