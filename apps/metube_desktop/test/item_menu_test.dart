import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/clip_handover.dart';
import 'package:metube_desktop/features/library/item_menu.dart';
import 'package:metube_desktop/features/library/library_item_view.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

LibraryItem _clip({bool onServer = true, String? localPath}) => LibraryItem(
  canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
  title: 'Night Drive',
  onServer: onServer,
  serverFilename: onServer ? 'Night Drive.mp4' : null,
  localPath: localPath,
  timestamp: DateTime(2026, 10, 20),
);

void main() {
  group('what the menu offers, by the clip', () {
    final l = lookupMTLocalizations(const Locale('en'));
    List<ItemChoice?> choices(LibraryItem item, {bool hasFile = false}) => [
      for (final e in itemMenuEntries(l, item, hasFile: hasFile).skip(5))
        e.value,
    ];

    test('playing comes first, each with its key, apart from the rest', () {
      final entries = itemMenuEntries(l, _clip(), hasFile: false);
      expect(
        [for (final e in entries.take(5)) e.value],
        [
          ItemChoice.play,
          ItemChoice.playNext,
          ItemChoice.readingRoom,
          ItemChoice.favorite,
          null,
        ],
      );
      expect([
        for (final e in entries.take(4)) e.shortcut,
      ], everyElement(isNotNull));
    });

    test("**the guard**: then the phone's order, and deleting last, apart and "
        'in the error colour', () {
      expect(choices(_clip()), [
        ItemChoice.makeOffline,
        ItemChoice.copyLink,
        ItemChoice.copyFile,
        ItemChoice.openOriginal,
        ItemChoice.addToList,
        ItemChoice.tags,
        ItemChoice.download,
        null,
        ItemChoice.deleteFromServer,
      ]);
      final last = itemMenuEntries(l, _clip(), hasFile: false).last;
      expect(last.danger, isTrue);
    });

    test('a clip kept here offers its folder and removing the copy, not '
        'making it again', () {
      expect(choices(_clip(localPath: r'C:\x.mp4'), hasFile: true), [
        ItemChoice.copyLink,
        ItemChoice.copyFile,
        ItemChoice.showInFolder,
        ItemChoice.openWith,
        ItemChoice.openOriginal,
        ItemChoice.addToList,
        ItemChoice.tags,
        ItemChoice.download,
        ItemChoice.removeLocalCopy,
        null,
        ItemChoice.deleteFromServer,
      ]);
    });

    test('**the guard**: a clip only on this computer is never offered the '
        "server's actions, and deleting it is deleting its file", () {
      expect(
        choices(_clip(onServer: false, localPath: r'C:\x.mp4'), hasFile: true),
        [
          ItemChoice.copyLink,
          ItemChoice.copyFile,
          ItemChoice.showInFolder,
          ItemChoice.openWith,
          ItemChoice.openOriginal,
          ItemChoice.addToList,
          ItemChoice.tags,
          null,
          ItemChoice.deleteLocal,
        ],
      );
    });
  });

  group('in the library', () {
    Future<ShellHarness> open(
      WidgetTester tester, {
      List<LibraryItem>? dragged,
      List<LibraryItem>? library,
    }) async {
      ShellHarness.useWindow(tester, const Size(1440, 900));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': ''}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final h = ShellHarness(
        library: library ?? [_clip()],
        server: ServerConfig(baseUrl: 'http://nas:8081'),
        overrides: [
          if (dragged != null)
            clipDragProvider.overrideWithValue((item, child) {
              dragged.add(item);
              return child;
            }),
        ],
      );
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      return h;
    }

    Future<void> rightClick(WidgetTester tester, Finder on) async {
      await tester.tapAt(
        tester.getCenter(on),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('**the guard**: a right click on a card opens its menu, and '
        'deleting asks first, then deletes by the canonical URL', (
      tester,
    ) async {
      final h = await open(tester);
      await rightClick(tester, find.text('Night Drive'));
      expect(find.text('Copy link'), findsOneWidget);
      await tester.tap(find.text('Delete from server'));
      await tester.pumpAndSettle();
      // Cancelled: nothing goes.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.api.deleted, isEmpty);

      await rightClick(tester, find.text('Night Drive'));
      await tester.tap(find.text('Delete from server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(h.api.deleted, [
        ['https://youtu.be/aaaaaaaaaaa'],
      ]);
    });

    for (final arabic in [false, true]) {
      testWidgets('**the guard**: the menu opens on the reading side of the '
          'pointer (${arabic ? 'left, in Arabic' : 'right, in English'})', (
        tester,
      ) async {
        if (arabic) ShellHarness.useArabic(tester);
        // A row of cards across the window; the pointer goes on the one in
        // the half where Flutter alone would open the menu the wrong way.
        await open(
          tester,
          library: [
            for (var i = 0; i < 4; i++)
              LibraryItem(
                canonicalUrl: 'https://youtu.be/clip$i',
                title: 'Clip $i',
                onServer: true,
                serverFilename: 'Clip $i.mp4',
                timestamp: DateTime(2026, 10, 20),
              ),
          ],
        );
        final cards = [
          for (final e in find.byType(LibraryItemView).evaluate())
            tester.getRect(find.byWidget(e.widget)),
        ]..sort((a, b) => a.left.compareTo(b.left));
        // The second card from the far edge: in the half where Flutter
        // alone would open the menu backwards, yet with room for it before
        // the content's edge turns it back.
        final at = (arabic ? cards[1] : cards[cards.length - 2]).center;
        await tester.tapAt(
          at,
          buttons: kSecondaryMouseButton,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        final menu = tester.getRect(
          find.byType(PopupMenuItem<ItemChoice>).first,
        );
        if (arabic) {
          expect(menu.right, lessThanOrEqualTo(at.dx + 1));
        } else {
          expect(menu.left, greaterThanOrEqualTo(at.dx - 1));
        }
      });
    }

    testWidgets('**the guard**: every clip in the library can be dragged out', (
      tester,
    ) async {
      final dragged = <LibraryItem>[];
      await open(tester, dragged: dragged);
      expect([
        for (final i in dragged) i.canonicalUrl,
      ], contains('https://youtu.be/aaaaaaaaaaa'));
    });
  });
}
