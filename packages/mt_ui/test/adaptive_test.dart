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

      await pump(tester, const Size(1280, 800), accessories: const [mini]);
      final wide = tester.getRect(find.byKey(const Key('mini')));
      expect(wide.bottom, 800);
      expect(wide.width, MTBreakpoint.readable);
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
}
