import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/features/palette/palette_grow.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

/// The palette opens out of the search box that was clicked, not somewhere
/// else in the window (owner's request 2026-11-11).
void main() {
  group('where it stands', () {
    const box = Rect.fromLTWH(200, 6, 360, 36);
    const window = Size(1440, 900);

    test('left to right: the field over the box, wider toward the end', () {
      final frame = paletteFrame(
        box: box,
        window: window,
        direction: TextDirection.ltr,
      );
      expect(frame.left, box.left - MTSpace.md);
      // A box near the top of the window: the card stays inside it.
      expect(frame.top, 0);
      expect(frame.width, paletteWidth);
    });

    test('right to left: it keeps the box\'s right edge and widens left', () {
      const rtlBox = Rect.fromLTWH(880, 6, 360, 36);
      final frame = paletteFrame(
        box: rtlBox,
        window: window,
        direction: TextDirection.rtl,
      );
      expect(frame.right, rtlBox.right + MTSpace.md);
      expect(frame.width, paletteWidth);
    });

    test('a narrow window keeps it whole inside', () {
      const small = Size(700, 560);
      final frame = paletteFrame(
        box: const Rect.fromLTWH(300, 6, 300, 36),
        window: small,
        direction: TextDirection.ltr,
      );
      expect(frame.left, greaterThanOrEqualTo(MTSpace.lg));
      expect(frame.right, lessThanOrEqualTo(small.width - MTSpace.lg));
    });
  });

  group('in the window', () {
    Future<void> open(WidgetTester tester) async {
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
        library: [
          LibraryItem(
            canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
            title: 'Pool layouts compared',
            uploader: 'Field Notes',
            onServer: true,
            timestamp: DateTime(2026, 10, 20),
            sizeBytes: 100,
          ),
        ],
      );
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
    }

    Future<void> expectOpensOutOfTheBox(
      WidgetTester tester,
      String boxHint,
    ) async {
      final box = tester.getRect(
        find
            .ancestor(of: find.text(boxHint), matching: find.byType(Material))
            .first,
      );
      await tester.tap(find.text(boxHint));
      await tester.pumpAndSettle();
      final field = tester.getRect(find.byType(TextField).last);
      // The field the user types in stands where the box was: the same
      // top, the same start edge.
      expect(field.top, moreOrLessEquals(box.top, epsilon: 1));
      final rtl =
          Directionality.of(tester.element(find.byType(TextField).last)) ==
          TextDirection.rtl;
      expect(
        rtl ? field.right : field.left,
        moreOrLessEquals(rtl ? box.right : box.left, epsilon: 1),
        reason: 'field $field, box $box',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    }

    testWidgets('**the guard**: clicked, the box opens into the palette in '
        'its own place', (tester) async {
      await open(tester);
      await expectOpensOutOfTheBox(tester, 'Search titles and what was said…');
    });

    testWidgets('**the guard**: in Arabic it keeps the box\'s right edge', (
      tester,
    ) async {
      ShellHarness.useArabic(tester);
      await open(tester);
      await expectOpensOutOfTheBox(tester, 'ابحث في العناوين وما قيل…');
    });
  });
}
