import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

void main() {
  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return context;
  }

  // Owner's request 2026-10-15: every error that shows also reaches the
  // log, including the ones nobody logged on purpose.
  testWidgets('an error shown is written down once, and only errors', (
    tester,
  ) async {
    final written = <String>[];
    mtErrorSnackLog = written.add;
    addTearDown(() => mtErrorSnackLog = null);
    final context = await host(tester);

    showMTSnack(context, 'it broke', type: MTSnackType.error);
    showMTSnack(
      context,
      'logged already',
      type: MTSnackType.error,
      logged: true,
    );
    showMTSnack(context, 'saved', type: MTSnackType.success);
    showMTSnack(context, 'note');

    expect(written, ['it broke']);
  });

  // Field report 2026-10-15: progress read in steps jumped from one figure
  // to the next.
  testWidgets('the progress glides to a new reading', (tester) async {
    Widget card(double progress) => MaterialApp(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      home: Scaffold(
        body: MTDownloadProgressCard(
          title: 'clip',
          statusText: 'on the server',
          progress: progress,
        ),
      ),
    );
    await tester.pumpWidget(card(0.3));
    expect(find.text('30%'), findsOneWidget);

    await tester.pumpWidget(card(0.9));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('30%'), findsNothing);
    expect(find.text('90%'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('90%'), findsOneWidget);
  });
}
