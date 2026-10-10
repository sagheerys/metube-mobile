import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The library's modes on a tablet (approved mock-up, 2026-10-10)**:
/// cards and compact rows gain columns, the list becomes a table, and a
/// phone keeps exactly the single column it had.
void main() {
  const count = 12;

  Widget item(MTLibraryLayout layout, int i, MTMediaColumns? columns) {
    final key = Key('item-$i');
    final title = i.isEven
        ? 'Homelab Hour — Ep. 12: Backups that actually restore'
        : 'رحلة إلى جبال السروات';
    if (columns != null) {
      return MTMediaRow(
        key: key,
        columns: columns,
        title: title,
        subtitle: 'Homelab Hour',
        duration: '1:02:33',
        size: '412.7 MB',
        added: '14 hours ago',
        tags: const ['homelab', 'backup'],
        location: MTMediaLocation.onServer,
        locationLabel: 'Server',
        favorite: i == 0,
        onFavoriteToggle: () {},
        onMore: () {},
      );
    }
    return switch (layout) {
      MTLibraryLayout.cards || MTLibraryLayout.grid => MTMediaGridCard(
        key: key,
        feed: layout == MTLibraryLayout.cards,
        title: title,
        subtitle: 'Homelab Hour · 14 hours ago',
        duration: '3:10',
        onMore: () {},
      ),
      _ => MTMediaCard(
        key: key,
        compact: layout == MTLibraryLayout.compact,
        title: title,
        subtitle: 'Homelab Hour · 14 hours ago',
        onMore: () {},
      ),
    };
  }

  /// [window] is the screen; [library] is the width the library actually
  /// has beside the rail and, when open, the player panel.
  Future<void> pump(
    WidgetTester tester,
    MTLibraryLayout layout, {
    Size window = const Size(1280, 800),
    double? library,
    double scale = 1,
    bool location = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(
              width: library ?? window.width,
              child: CustomScrollView(
                slivers: [
                  MTLibrarySliver(
                    layout: layout,
                    itemCount: count,
                    showLocation: location,
                    itemBuilder: (context, i, columns) =>
                        item(layout, i, columns),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// How many items share the first item's row.
  int perRow(WidgetTester tester) {
    final top = tester.getTopLeft(find.byKey(const Key('item-0'))).dy;
    var n = 0;
    for (var i = 0; i < count; i++) {
      final found = find.byKey(Key('item-$i'));
      if (found.evaluate().isEmpty) break;
      if (tester.getTopLeft(found).dy == top) n++;
    }
    return n;
  }

  group('a phone keeps one column', () {
    for (final layout in MTLibraryLayout.values.where(
      (l) => l != MTLibraryLayout.grid,
    )) {
      testWidgets(layout.name, (tester) async {
        await pump(tester, layout, window: const Size(411, 914));
        expect(perRow(tester), 1);
        expect(find.byType(MTMediaRowHeader), findsNothing);
        expect(find.byType(MTMediaRow), findsNothing);
      });
    }
  });

  group('cards on a tablet', () {
    testWidgets('two across beside the player panel, three without it', (
      tester,
    ) async {
      await pump(tester, MTLibraryLayout.cards, library: 754);
      expect(perRow(tester), 2);
      await pump(tester, MTLibraryLayout.cards, library: 1155);
      expect(perRow(tester), 3);
    });

    testWidgets('two across held upright', (tester) async {
      await pump(
        tester,
        MTLibraryLayout.cards,
        window: const Size(800, 1280),
        library: 675,
      );
      expect(perRow(tester), 2);
    });
  });

  group('compact rows on a tablet', () {
    testWidgets('two across beside the panel, three without it', (
      tester,
    ) async {
      await pump(tester, MTLibraryLayout.compact, library: 754);
      expect(perRow(tester), 2);
      await pump(tester, MTLibraryLayout.compact, library: 1155);
      expect(perRow(tester), 3);
    });
  });

  group('the list as a table', () {
    MTMediaColumns columns(WidgetTester tester) =>
        tester.widget<MTMediaRowHeader>(find.byType(MTMediaRowHeader)).columns;

    testWidgets('beside the panel: length, size and source, no date', (
      tester,
    ) async {
      await pump(tester, MTLibraryLayout.list, library: 754);
      final c = columns(tester);
      expect((c.size, c.added, c.location), (true, false, true));
      expect(find.text('#homelab'), findsNothing);
    });

    testWidgets('the full width adds the date and the tags', (tester) async {
      await pump(tester, MTLibraryLayout.list, library: 1155);
      final c = columns(tester);
      expect((c.size, c.added, c.location), (true, true, true));
      expect(find.text('#homelab'), findsWidgets);
    });

    testWidgets('upright drops the size first', (tester) async {
      await pump(
        tester,
        MTLibraryLayout.list,
        window: const Size(800, 1280),
        library: 675,
      );
      final c = columns(tester);
      expect((c.size, c.added), (false, false));
    });

    testWidgets('Lite has no source column', (tester) async {
      await pump(tester, MTLibraryLayout.list, library: 754, location: false);
      expect(columns(tester).location, isFalse);
    });

    testWidgets('the largest font falls back to the phone row', (tester) async {
      await pump(tester, MTLibraryLayout.list, library: 754, scale: 2);
      expect(find.byType(MTMediaRowHeader), findsNothing);
      expect(find.byType(MTMediaCard), findsWidgets);
    });

    testWidgets('every cell sits under its heading', (tester) async {
      await pump(tester, MTLibraryLayout.list, library: 1155);
      final l10n = tester.element(find.byType(MTMediaRowHeader)).mtl;
      final heading = tester.getRect(find.text(l10n.columnLength));
      final cell = tester.getRect(find.textContaining('1:02:33').first);
      expect(cell.right, moreOrLessEquals(heading.right, epsilon: 1));
    });
  });

  testWidgets('no layout overflows a tablet at any font scale', (tester) async {
    const shapes = [
      (Size(1280, 800), 754.0),
      (Size(1280, 800), 1155.0),
      (Size(800, 1280), 675.0),
      (Size(960, 600), 434.0),
      (Size(960, 600), 835.0),
      (Size(600, 960), 475.0),
      // The grid used to overflow on a phone too, from a fixed cell ratio.
      (Size(320, 534), 320.0),
      (Size(411, 914), 411.0),
    ];
    for (final (window, library) in shapes) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final layout in MTLibraryLayout.values) {
          await pump(
            tester,
            layout,
            window: window,
            library: library,
            scale: scale,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$window $library $scale ${layout.name}',
          );
        }
      }
    }
  });
}
