import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Field report 2026-09-30:** "The Modern Coder Bootcamp
/// (with AI) - New Course!" read "!(with AI) - New Course" under the Arabic
/// interface. A title keeps its own direction, and still lines up with
/// the interface.
void main() {
  Widget host(Widget child, {Locale locale = const Locale('ar')}) =>
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        locale: locale,
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  RichText titleOf(WidgetTester tester, String title) =>
      tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == title,
        ),
      );

  const english = 'The Modern Coder Bootcamp (with AI) - New Course!';
  const arabic = 'رحلة إلى جبال السروات!';

  testWidgets('list card: an English title under Arabic', (tester) async {
    await tester.pumpWidget(host(const MTMediaCard(title: english)));
    final title = titleOf(tester, english);
    expect(title.textDirection, TextDirection.ltr);
    expect(title.textAlign, TextAlign.right);
  });

  testWidgets('grid card: an Arabic title under English', (tester) async {
    await tester.pumpWidget(
      host(
        const SizedBox(width: 200, child: MTMediaGridCard(title: arabic)),
        locale: const Locale('en'),
      ),
    );
    final title = titleOf(tester, arabic);
    expect(title.textDirection, TextDirection.rtl);
    expect(title.textAlign, TextAlign.left);
  });

  test('the direction comes from the first letter', () {
    expect(mtTextDirectionOf('!Hello', TextDirection.rtl), TextDirection.ltr);
    expect(
      mtTextDirectionOf('2024 مرحبا', TextDirection.ltr),
      TextDirection.rtl,
    );
    expect(mtTextDirectionOf('123 !?', TextDirection.rtl), TextDirection.rtl);
  });
}
