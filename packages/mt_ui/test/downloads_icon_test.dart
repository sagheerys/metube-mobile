import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// The downloads icon moves only while something downloads.
void main() {
  Widget host(int active, {bool still = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: MaterialApp(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      home: Scaffold(
        body: Center(child: MTDownloadsIcon(active: active)),
      ),
    ),
  );

  // The glyph is drawn twice: the still tray first, the moving arrow last.
  Offset arrow(WidgetTester tester) =>
      tester.getTopLeft(find.byIcon(Icons.download_rounded).last);
  Offset tray(WidgetTester tester) =>
      tester.getTopLeft(find.byIcon(Icons.download_rounded).first);

  group('the drop', () {
    test('rests upright for most of the loop', () {
      expect(mtDownloadDrop(0), (0.0, 1.0));
      expect(mtDownloadDrop(0.4), (0.0, 1.0));
    });

    test('falls and fades, then returns from above', () {
      final (falling, fading) = mtDownloadDrop(0.7);
      expect(falling, greaterThan(0));
      expect(fading, lessThan(1));
      final (rising, _) = mtDownloadDrop(0.8);
      expect(rising, lessThan(0));
      final (end, shown) = mtDownloadDrop(1);
      expect(end, closeTo(0, 1e-9));
      expect(shown, closeTo(1, 1e-9));
    });
  });

  testWidgets('with downloads running the arrow moves', (tester) async {
    await tester.pumpWidget(host(2));
    final rest = arrow(tester);
    final line = tray(tester);
    await tester.pump(MTDownloadsIcon.period * 0.65);
    expect(arrow(tester).dy, greaterThan(rest.dy));
    // Only the arrow: the line it drops into does not move.
    expect(tray(tester), line);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('with none it stands still and shows no count', (tester) async {
    await tester.pumpWidget(host(0));
    final rest = arrow(tester);
    await tester.pump(MTDownloadsIcon.period * 0.65);
    expect(arrow(tester), rest);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('the last download finishing stops it upright', (tester) async {
    await tester.pumpWidget(host(1));
    final rest = arrow(tester);
    await tester.pump(MTDownloadsIcon.period * 0.65);
    await tester.pumpWidget(host(0));
    await tester.pumpAndSettle();
    expect(arrow(tester), rest);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion keeps it still, count and all', (tester) async {
    await tester.pumpWidget(host(3, still: true));
    final rest = arrow(tester);
    await tester.pump(MTDownloadsIcon.period * 0.65);
    expect(arrow(tester), rest);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('3'), findsOneWidget);
  });
}
