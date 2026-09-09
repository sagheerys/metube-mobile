import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/src/widgets/mt_drag_to_dismiss.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The guard for "dragging down returns the audio screen to the mini
/// player"** (requested 2026-09-04). A short drag returns to place; a long
/// one or a fling closes.
void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.lite, Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: MTDragToDismiss(
                        child: SizedBox.expand(child: Text('صوت')),
                      ),
                    ),
                  ),
                ),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    expect(find.text('صوت'), findsOneWidget);
  }

  testWidgets('a short drag springs back and does not close', (tester) async {
    await pumpPage(tester);
    await tester.drag(
      find.text('صوت'),
      Offset(0, MTMotion.dismissDragDistance / 2),
    );
    await tester.pumpAndSettle();
    expect(find.text('صوت'), findsOneWidget);
    final transform = tester.widget<Transform>(find.byType(Transform).first);
    expect(
      transform.transform.getTranslation().y,
      0,
      reason: 'عادت إلى موضعها بلا بقايا إزاحة',
    );
  });

  testWidgets('a drag past the distance closes it', (tester) async {
    await pumpPage(tester);
    await tester.drag(
      find.text('صوت'),
      Offset(0, MTMotion.dismissDragDistance + 40),
    );
    await tester.pumpAndSettle();
    expect(find.text('صوت'), findsNothing);
    expect(find.text('افتح'), findsOneWidget);
  });

  testWidgets('a quick short fling closes it too', (tester) async {
    await pumpPage(tester);
    await tester.fling(
      find.text('صوت'),
      const Offset(0, 60),
      MTMotion.dismissFlingVelocity * 2,
    );
    await tester.pumpAndSettle();
    expect(find.text('صوت'), findsNothing);
  });

  testWidgets('dragging upwards does nothing', (tester) async {
    await pumpPage(tester);
    await tester.drag(find.text('صوت'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('صوت'), findsOneWidget);
  });
}
