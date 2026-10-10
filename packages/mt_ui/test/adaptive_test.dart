import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Tablet guards (2026-10-10)**: a phone keeps exactly the layout it had,
/// and a wide window trades the bottom bar for a side rail.
void main() {
  const items = [
    MTNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'أ'),
    MTNavItem(icon: Icons.list_outlined, selectedIcon: Icons.list, label: 'ب'),
    MTNavItem(icon: Icons.settings, selectedIcon: Icons.settings, label: 'ج'),
  ];

  Future<void> pump(
    WidgetTester tester,
    Size size, {
    TextDirection direction = TextDirection.rtl,
    List<Widget> accessories = const [],
    Widget? endPane,
    Widget? fab,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: Directionality(
          textDirection: direction,
          child: MTAdaptiveScaffold(
            items: items,
            selectedIndex: 0,
            onSelected: (_) {},
            body: const SizedBox.expand(key: Key('body')),
            bottomAccessories: accessories,
            endPane: endPane,
            floatingActionButton: fab,
          ),
        ),
      ),
    );
  }

  group('window classes', () {
    test('the edges fall on 600 and 840, measured on the width', () {
      expect(MTBreakpoint.classOf(599), MTWindowClass.compact);
      expect(MTBreakpoint.classOf(600), MTWindowClass.medium);
      expect(MTBreakpoint.classOf(839), MTWindowClass.medium);
      expect(MTBreakpoint.classOf(840), MTWindowClass.expanded);
    });
  });

  group('the shell frame', () {
    testWidgets('a phone keeps the bottom bar and has no rail', (tester) async {
      await pump(tester, const Size(411, 914));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('a phone held sideways is still a phone below 600 wide', (
      tester,
    ) async {
      await pump(tester, const Size(599, 360));
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    // The owner's 8-inch tablet (2026-10-10): 800x1280 pixels at 216 dpi,
    // and the app's window as measured on it, above the three-button bar.
    testWidgets('an 8-inch tablet of 593 points gets the rail on its side', (
      tester,
    ) async {
      await pump(tester, const Size(948, 544));
      expect(find.byType(NavigationRail), findsOneWidget);
      await pump(tester, const Size(593, 900));
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('the largest phones on their side keep the bar', (
      tester,
    ) async {
      for (final size in const [Size(1000, 480), Size(932, 430)]) {
        await pump(tester, size);
        expect(find.byType(NavigationBar), findsOneWidget, reason: '$size');
      }
    });

    testWidgets('a small tablet upright gets the rail instead of the bar', (
      tester,
    ) async {
      await pump(tester, const Size(600, 960));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('in Arabic the rail sits on the right, beside the content', (
      tester,
    ) async {
      await pump(tester, const Size(1280, 800));
      final rail = tester.getRect(find.byType(NavigationRail));
      final body = tester.getRect(find.byKey(const Key('body')));
      expect(rail.right, 1280);
      expect(body.right, lessThan(rail.left));
    });

    testWidgets('in English the rail sits on the left', (tester) async {
      await pump(tester, const Size(1280, 800), direction: TextDirection.ltr);
      expect(tester.getRect(find.byType(NavigationRail)).left, 0);
    });

    testWidgets('the accessories stay at the bottom in both shapes', (
      tester,
    ) async {
      const mini = SizedBox(key: Key('mini'), height: 60);
      await pump(tester, const Size(411, 914), accessories: const [mini]);
      final onPhone = tester.getRect(find.byKey(const Key('mini')));
      expect(
        onPhone.top,
        lessThan(tester.getRect(find.byType(NavigationBar)).top),
      );

      // The approved mock-up (2026-10-10): the mini player spans the
      // content beside the rail, not a centred column of the screen.
      await pump(tester, const Size(1280, 800), accessories: const [mini]);
      final wide = tester.getRect(find.byKey(const Key('mini')));
      final rail = tester.getRect(find.byType(NavigationRail));
      expect(wide.bottom, 800);
      expect(wide.right, lessThanOrEqualTo(rail.left));
      expect(wide.left, 0);
    });
  });

  group('readable width', () {
    testWidgets('is a no-op on a phone', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(411, 914);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MTReadableWidth(child: SizedBox.expand(key: Key('c'))),
      );
      expect(tester.getSize(find.byKey(const Key('c'))).width, 411);
    });

    testWidgets('caps and centres the content on a tablet', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MTReadableWidth(child: SizedBox.expand(key: Key('c'))),
      );
      final rect = tester.getRect(find.byKey(const Key('c')));
      expect(rect.width, MTBreakpoint.readable);
      expect(rect.left, (1280 - MTBreakpoint.readable) / 2);
    });
  });

  group('the end pane', () {
    const pane = SizedBox.expand(key: Key('pane'));
    const fab = SizedBox(key: Key('fab'), width: 100, height: 50);

    testWidgets('stands at the far side of a tablet held sideways', (
      tester,
    ) async {
      await pump(tester, const Size(1280, 800), endPane: pane, fab: fab);
      final rect = tester.getRect(find.byKey(const Key('pane')));
      final body = tester.getRect(find.byKey(const Key('body')));
      expect(rect.width, MTBreakpoint.sidePanel);
      expect(rect.left, 0, reason: 'Arabic: the end side is the left');
      expect(body.left, greaterThan(rect.right));
      // The add button moves off the pane, to the content's own corner.
      final button = tester.getRect(find.byKey(const Key('fab')));
      expect(button.left, greaterThan(rect.right));
    });

    testWidgets('gives way on a tablet held upright', (tester) async {
      await pump(tester, const Size(800, 1280), endPane: pane);
      expect(find.byKey(const Key('pane')), findsNothing);
    });

    testWidgets('a phone on its side keeps the bottom bar and no pane', (
      tester,
    ) async {
      // Wider than 840, as inside the video player: the shell beneath must
      // not change shape.
      await pump(tester, const Size(914, 411), endPane: pane);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byKey(const Key('pane')), findsNothing);
    });
  });
}
