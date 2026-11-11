import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// A clip's title can be selected and copied, to look it up elsewhere
/// (owner's request 2026-11-11).
void main() {
  const title =
      'Building a Cedar Bench, Part 2 - Joinery, the long version with '
      'every cut explained from the first board to the last';

  testWidgets('**the guard**: selected whole and copied, it is the whole '
      'title, the part cut off at two lines too', (tester) async {
    // A running app, as on the phone: there a touch on the menu used to
    // count as a tap elsewhere and drop the selection (owner's report
    // 2026-11-11), which a test in the background never saw.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.lite, Brightness.light),
        home: const Scaffold(
          body: SizedBox(
            width: 240,
            child: MTForeignText(title, maxLines: 2, selectable: true),
          ),
        ),
      ),
    );
    // A finger: frames pass between touching the menu and lifting off.
    Future<void> touch(Finder target) async {
      final finger = await tester.startGesture(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 80));
      await finger.up();
      await tester.pumpAndSettle();
    }

    await tester.longPress(find.text(title));
    await tester.pumpAndSettle();
    await touch(find.text('Select all'));
    await touch(find.text('Copy'));
    expect(copied, title);
  });

  testWidgets('**the guard**: a tap anywhere else lets the selection go, '
      'with its menu', (tester) async {
    // A running app: Flutter keeps a selection through a loss of focus
    // while the app is in the background.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.lite, Brightness.light),
        home: const Scaffold(
          body: Column(
            children: [
              SizedBox(height: 300, child: ColoredBox(color: Colors.black)),
              MTForeignText(title, maxLines: 2, selectable: true),
            ],
          ),
        ),
      ),
    );
    await tester.longPress(find.text(title));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    // Where the picture would be.
    await tester.tapAt(const Offset(200, 150));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('not asked to, it stays plain text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MTForeignText(title, maxLines: 2)),
    );
    expect(find.byType(SelectionArea), findsNothing);
  });
}
