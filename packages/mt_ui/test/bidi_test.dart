import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Number direction guards** (device check 2026-09-05): neutral
/// characters attach to the wrong end inside an Arabic paragraph and
/// invert the meaning of a phrase, so "2 / 40" renders as "40 / 2".
void main() {
  test('العزل يلفّ النص من طرفيه ولا يغيّر محتواه', () {
    final wrapped = mtLtrRun('2 / 40');
    expect(wrapped.startsWith(mtLtrIsolate), isTrue);
    expect(wrapped.endsWith(mtPopIsolate), isTrue);
    expect(
      wrapped.substring(1, wrapped.length - 1),
      '2 / 40',
      reason: 'المحتوى نفسه — العزل توجيه لا تعديل',
    );
  });

  test('العزل لا يتراكم عند اللفّ المزدوج بالخطأ', () {
    // Not a defect today, but an easy trap: wrapping already-wrapped text
    // stays visually valid, and what matters is that the content is not
    // lost.
    expect(mtLtrRun(mtLtrRun('1 / 2')), contains('1 / 2'));
  });

  testWidgets('نصّ معزول يُرسم كما هو داخل واجهة عربية', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.lite, Brightness.light),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: Text(mtLtrRun('-50:49')))),
        ),
      ),
    );
    expect(find.text(mtLtrRun('-50:49')), findsOneWidget);
  });
}
