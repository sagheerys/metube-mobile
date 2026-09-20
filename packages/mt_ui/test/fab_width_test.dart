import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The floating button is the one widget nothing constrains.**
///
/// It sits in `Scaffold.floatingActionButton`, a slot that hands its child
/// unbounded width, so the button grows to whatever its label asks for and
/// walks off the right edge without anyone noticing on a normal phone.
///
/// Measured 2026-09-20 by the device matrix while adding م-71: the label
/// "Follow a channel" at text scale ×1.3 on a 320dp screen overflowed by
/// **35 pixels**. The shipped labels ("Add link", "Paste link") are short
/// enough to hide the fault — and م-50 adds languages whose words are not,
/// so this guards the translations that do not exist yet.
void main() {
  Widget host(String label, {required Size size, required double scale}) =>
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          home: Scaffold(
            floatingActionButton: MTFab(label: label, onPressed: () {}),
            body: const SizedBox.shrink(),
          ),
        ),
      );

  /// Far longer than anything in either arb file today: the point is that
  /// a translator cannot break the layout from a text file.
  const overlyLongLabel = 'Follow a channel and keep it forever, please';

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('a long label does not overflow at 320dp, scale $scale', (
      tester,
    ) async {
      const size = Size(320, 534);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(overlyLongLabel, size: size, scale: scale));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'MTFab overflowed at ×$scale',
      );
    });
  }

  testWidgets('and the button stays inside the screen it is drawn on', (
    tester,
  ) async {
    const size = Size(320, 534);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(overlyLongLabel, size: size, scale: 1.3));
    await tester.pumpAndSettle();

    // Not merely "no exception": a Row can be clipped by an ancestor and
    // still be wider than the display.
    expect(tester.getSize(find.byType(MTFab)).width, lessThanOrEqualTo(320));
  });

  testWidgets('a short label is still laid out at its natural width', (
    tester,
  ) async {
    const size = Size(411, 914);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host('Add link', size: size, scale: 1.0));
    await tester.pumpAndSettle();

    // The bound must not stretch the button: it is a pill that hugs its
    // label, not a full-width bar.
    expect(tester.getSize(find.byType(MTFab)).width, lessThan(240));
    expect(find.text('Add link'), findsOneWidget);
  });
}
