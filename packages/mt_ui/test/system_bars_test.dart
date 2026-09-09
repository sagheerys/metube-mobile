import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Guards for the bottom navigation buttons** (field report
/// 2026-09-04): everything was fine with gestures, and with the three
/// buttons the last thing in a sheet was clipped, because a bottom sheet
/// reaches the screen edge and `useSafeArea` does not protect the bottom.
void main() {
  const navBar = 48.0; // ارتفاع شريط الأزرار الثلاثة في أندرويد.

  Widget host(Widget child, {double bottom = navBar, double keyboard = 0}) =>
      MaterialApp(
        theme: mtTheme(MTVariant.lite, Brightness.light),
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            padding: EdgeInsets.only(bottom: keyboard > 0 ? 0 : bottom),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: child),
          ),
        ),
      );

  Widget urlSheet(TextEditingController controller) => MTUrlInputSheet(
    title: 'إضافة رابط',
    urlHint: 'الصق الرابط هنا…',
    controller: controller,
    qualities: const [MTQualityOption(value: 'best', label: 'الأفضل')],
    selectedQuality: 'best',
    onQualitySelected: (_) {},
    startLabel: 'ابدأ التحميل',
    onStart: () {},
  );

  group('mtSheetBottomPad', () {
    testWidgets('زر «ابدأ التحميل» يبقى فوق شريط الأزرار لا تحته', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(urlSheet(controller)));

      final screen = tester.getSize(find.byType(MaterialApp)).height;
      final button = tester.getRect(find.text('ابدأ التحميل'));
      // The guard: the bottom of the button never enters the navigation
      // area.
      expect(button.bottom, lessThanOrEqualTo(screen - navBar));
    });

    testWidgets('لوحة المفاتيح مفتوحة ⇒ لا تُجمع المسافتان مرتين', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(urlSheet(controller), keyboard: 300));

      final screen = tester.getSize(find.byType(MaterialApp)).height;
      final button = tester.getRect(find.text('ابدأ التحميل'));
      // Above the keyboard by the design spacing alone, with no extra gap
      // the
      // size of a button bar the keyboard already covers.
      expect(button.bottom, lessThanOrEqualTo(screen - 300));
      expect(button.bottom, greaterThan(screen - 300 - navBar));
    });

    testWidgets('بلا أشرطة نظام ⇒ مسافة التصميم وحدها', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(urlSheet(controller), bottom: 0));

      final screen = tester.getSize(find.byType(MaterialApp)).height;
      final button = tester.getRect(find.text('ابدأ التحميل'));
      expect(button.bottom, greaterThan(screen - navBar));
    });
  });

  group('MTSystemBars', () {
    SystemUiOverlayStyle styleOf(WidgetTester tester) =>
        tester
                .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
                  find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
                )
                .value;

    testWidgets('نهاراً: أيقونات داكنة وشريط شفاف بلا حجاب تباين', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mtTheme(MTVariant.lite, Brightness.light),
          home: const MTSystemBars(child: SizedBox.shrink()),
        ),
      );
      final style = styleOf(tester);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, Colors.transparent);
      // The most important guard: without this, Android 15+ draws a scrim
      // behind the buttons, showing a band of a different colour from the
      // app's
      // own bar above it.
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    });

    testWidgets('ليلاً: أيقونات فاتحة', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.dark),
          home: const MTSystemBars(child: SizedBox.shrink()),
        ),
      );
      final style = styleOf(tester);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
      expect(style.statusBarIconBrightness, Brightness.light);
    });
  });
}
