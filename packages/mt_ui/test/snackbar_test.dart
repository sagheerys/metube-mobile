import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Guard: the bar dismisses itself, with or without an action.**
///
/// Field report 2026-09-04: "the notices that appear over the add-link
/// button never go away, they have no timer. I want them to behave like
/// the added-to-favourites notice."
///
/// The cause is in Flutter itself: `SnackBar.persist = persist ?? action
/// != null`, meaning **every bar with a button stays forever** until the
/// user dismisses it. "Added to favourites" has no button and disappears;
/// "download started · change quality" has one and stays. This test fails
/// if `persist` ever falls back to its implicit value.
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
    await tester.pumpWidget(
      host(
        (context) => showMTSnack(
          context,
          'رسالة',
          actionLabel: actionLabel,
          onAction: actionLabel == null ? null : () {},
        ),
      ),
    );
    await tester.tap(find.text('اعرض'));
    // **Until the entrance animation completes**: `ScaffoldMessenger` only
    // schedules the hide timer after `isCompleted`, so a single pump shows
    // the bar with no timer at all.
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
    expect(
      find.text('رسالة'),
      findsNothing,
      reason: 'persist: false — وإلا بقي الشريط فوق زر إضافة رابط للأبد',
    );
  });
}
