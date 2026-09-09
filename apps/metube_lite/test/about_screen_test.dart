import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/features/settings/about_screen.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'device_matrix.dart';

/// **شاشة «حول» بعد فتح المصدر (بلاغ المالك 2026-09-09).**
///
/// كانت تقول «جميع الحقوق محفوظة» ولا تذكر الرخصة ولا تنفي الانتساب
/// لمشروع MeTube، وتطبع رقم البناء `+1` في وجه المستخدم.
void main() {
  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'MeTube Lite',
        packageName: 'com.yasir.metubelite',
        version: '2.0.0',
        buildNumber: '7',
        buildSignature: '',
      ));

  Widget host() => MaterialApp(
        theme: mtTheme(MTVariant.lite, Brightness.light),
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: const AboutScreen(),
      );

  /// **سطح اختبار طويل**: `ListView` كسولة، وأقسام «حول» الأخيرة لا
  /// تُبنى أصلاً على 600 نقطة — فيفشل البحث عنها بلا أن يكون في الشاشة عطل.
  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 2600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
  }

  testWidgets('الإصدار بلا رقم البناء', (tester) async {
    await open(tester);
    final l10n = tester.element(find.byType(AboutScreen)).mtl;

    expect(find.text('${l10n.version} 2.0.0'), findsOneWidget);
    // **الحارس**: كان النصّ `2.0.0+7` — رقم البناء عدّاد داخلي لأندرويد.
    expect(find.textContaining('+7'), findsNothing);
  });

  testWidgets('الرخصة ونفي الانتساب ونفي الضمان معروضة', (tester) async {
    await open(tester);
    final l10n = tester.element(find.byType(AboutScreen)).mtl;

    expect(find.text(l10n.licensedUnder), findsOneWidget);
    expect(find.text(l10n.notAffiliated), findsOneWidget);
    expect(find.text(l10n.noWarranty), findsOneWidget);
    expect(find.text(l10n.copyright), findsOneWidget);
  });

  testWidgets('روابط المشروع وما بُني عليه موجودة', (tester) async {
    await open(tester);

    expect(find.text('sagheerys/metube-mobile'), findsOneWidget);
    expect(find.text('metube-mobile/issues'), findsOneWidget);
    expect(find.text('MeTube'), findsOneWidget);
    expect(find.text('yt-dlp'), findsOneWidget);
  });

  testWidgets('أيقونة التطبيق نفسها لا رمز عام', (tester) async {
    await open(tester);

    final image = tester.widget<Image>(find.byType(Image).first);
    // `Image.asset` مع `cacheWidth` تلفّ المزوّد في `ResizeImage`.
    final provider = image.image;
    final asset = provider is ResizeImage ? provider.imageProvider : provider;
    expect((asset as AssetImage).assetName, 'assets/icons/icon.png');
  });

  testWidgets('**مصفوفة الأجهزة**: «حول» بلا تجاوز إطار', (tester) async {
    await expectNoOverflow(tester, host);
  });
}
