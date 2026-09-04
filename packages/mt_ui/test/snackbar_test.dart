import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **حارس: الشريط يختفي وحده — بفعل أو بلا فعل.**
///
/// بلاغ المالك 2026-09-04: «الإشعارات التي تأتي فوق زر إضافة رابط لا
/// تذهب، لا يوجد لديها مؤقت — أريدها مثل زمن إشعار أُضيفت في المفضلة».
///
/// السبب في Flutter نفسه: `SnackBar.persist = persist ?? action != null`،
/// أي أن **كل شريط له زر يبقى للأبد** حتى يُزيحه المستخدم. «أُضيف
/// للمفضلة» بلا زر فيختفي — و«بدأ التحميل · تغيير الجودة» له زر فيبقى.
/// هذا الاختبار يسقط إن عاد `persist` إلى قيمته الضمنية.
void main() {
  Widget host(void Function(BuildContext context) onPressed) => MaterialApp(
        theme: mtTheme(MTVariant.lite, Brightness.light),
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => onPressed(context),
              child: const Text('اعرض'),
            ),
          ),
        ),
      );

  Future<void> show(WidgetTester tester, {String? actionLabel}) async {
    await tester.pumpWidget(host((context) => showMTSnack(
          context,
          'رسالة',
          actionLabel: actionLabel,
          onAction: actionLabel == null ? null : () {},
        )));
    await tester.tap(find.text('اعرض'));
    // **حتى تكتمل حركة الدخول**: `ScaffoldMessenger` لا يجدول مؤقت
    // الإخفاء إلا بعد `isCompleted` — نبضة واحدة تُظهر الشريط بلا مؤقت.
    await tester.pumpAndSettle();
    expect(find.text('رسالة'), findsOneWidget);
  }

  testWidgets('شريط بلا فعل يختفي بعد المهلة', (tester) async {
    await show(tester);
    await tester.pump(mtSnackDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('رسالة'), findsNothing);
  });

  testWidgets('شريط **له فعل** يختفي بعد المهلة نفسها', (tester) async {
    await show(tester, actionLabel: 'تغيير');
    expect(find.text('تغيير'), findsOneWidget);
    await tester.pump(mtSnackDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('رسالة'), findsNothing,
        reason: 'persist: false — وإلا بقي الشريط فوق زر إضافة رابط للأبد');
  });
}
