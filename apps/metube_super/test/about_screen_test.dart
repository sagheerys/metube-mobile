import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/settings/about_screen.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'device_matrix.dart';

/// **The About screen after open-sourcing (field report 2026-09-09).**
///
/// It said "all rights reserved", named neither the licence nor the absence
/// of any affiliation with the MeTube project, and printed the build number
/// `+1` in the user's face.
void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'MeTube Super',
      packageName: 'com.yasir.metubesuper',
      version: '2.0.0',
      buildNumber: '7',
      buildSignature: '',
    ),
  );

  Widget host() => MaterialApp(
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    locale: const Locale('ar'),
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    home: const AboutScreen(),
  );

  /// **A tall test surface**: the `ListView` is lazy and About's last
  /// sections are not built at all at 600 points, so searching for them
  /// fails without anything being wrong with the screen.
  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 2600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  testWidgets('the version, without the build number', (tester) async {
    await open(tester);
    final l10n = tester.element(find.byType(AboutScreen)).mtl;

    expect(find.text('${l10n.version} 2.0.0'), findsOneWidget);
    // **The guard**: the text used to be `2.0.0+7`, and the build number is
    // an internal Android counter.
    expect(find.textContaining('+7'), findsNothing);
  });

  testWidgets(
    'the licence, the non-affiliation notice and the warranty disclaimer are shown',
    (tester) async {
      await open(tester);
      final l10n = tester.element(find.byType(AboutScreen)).mtl;

      expect(find.text(l10n.licensedUnder), findsOneWidget);
      expect(find.text(l10n.notAffiliated), findsOneWidget);
      expect(find.text(l10n.noWarranty), findsOneWidget);
      expect(find.text(l10n.copyright), findsOneWidget);
    },
  );

  testWidgets('the project links and what it is built on are present', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('sagheerys/metube-mobile'), findsOneWidget);
    expect(find.text('metube-mobile/issues'), findsOneWidget);
    expect(find.text('MeTube'), findsOneWidget);
    expect(find.text('yt-dlp'), findsOneWidget);
  });

  testWidgets("the app's own icon, not a generic symbol", (tester) async {
    await open(tester);

    final image = tester.widget<Image>(find.byType(Image).first);
    // `Image.asset` with `cacheWidth` wraps the provider in a
    // `ResizeImage`.
    final provider = image.image;
    final asset = provider is ResizeImage ? provider.imageProvider : provider;
    expect((asset as AssetImage).assetName, 'assets/icons/icon.png');
  });

  testWidgets('**device matrix**: About does not overflow', (tester) async {
    await expectNoOverflow(tester, host);
  });
}
