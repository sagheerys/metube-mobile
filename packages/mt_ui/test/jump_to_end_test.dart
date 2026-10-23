import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

void main() {
  Widget host(ScrollController controller, {bool fresh = false}) => MaterialApp(
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    home: Scaffold(
      body: MTJumpToEnd(
        controller: controller,
        tooltip: 'Go to the newest',
        fresh: fresh,
        child: ListView.builder(
          controller: controller,
          padding: const EdgeInsets.only(bottom: MTJumpToEnd.reserve),
          itemCount: 300,
          // Uneven heights, like wrapped log lines: the end measured
          // before a jump is not the real one.
          itemBuilder: (_, i) =>
              SizedBox(height: i.isEven ? 20 : 44, child: Text('line $i')),
        ),
      ),
    ),
  );

  double opacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(MTJumpToEnd),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('hidden at first, out while scrolling down, gone on the '
      'way back up', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    expect(opacity(tester), 0);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(opacity(tester), 1);

    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(opacity(tester), 0);
  });

  testWidgets('one tap lands on the real end, then it hides', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_downward_rounded));
    await tester.pumpAndSettle();
    expect(controller.position.extentAfter, 0);
    expect(find.text('line 299'), findsOneWidget);
    expect(opacity(tester), 0);
  });

  testWidgets('hidden, it takes no taps', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    await tester.tap(
      find.byIcon(Icons.arrow_downward_rounded),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });

  testWidgets('new entries below bring it out with a dot', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(controller));
    await tester.pumpWidget(host(controller, fresh: true));
    await tester.pumpAndSettle();
    expect(opacity(tester), 1);
    expect(controller.offset, 0, reason: 'the reader is not moved');
  });
}
