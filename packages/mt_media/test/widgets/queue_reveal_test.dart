import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The queue opens on the song that is playing** (field report
/// 2026-09-26, reproduced on a real phone: the 27th song of a 30-song
/// playlist, and the queue sheet opened at the first song).
void main() {
  final songs = [
    for (var i = 0; i < 30; i++)
      PlaylistItem(
        canonicalUrl: 'https://x/$i',
        title: 'Song $i',
        isAudio: true,
      ),
  ];

  Future<void> open(
    WidgetTester tester, {
    required int current,
    bool nested = false,
  }) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: Scaffold(
          body: ConstrainedBox(
            // The sheet's own limit: 72% of the screen.
            constraints: const BoxConstraints(maxHeight: 914 * 0.72),
            child: MTQueuePanel(
              items: songs,
              currentIndex: current,
              nested: nested,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    // Fixed frames, not pumpAndSettle: the playing row's equaliser moves
    // for ever. Three frames cover the jump and the exact placement.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  bool onScreen(WidgetTester tester, String title) {
    final found = find.text(title);
    if (found.evaluate().isEmpty) return false;
    final rect = tester.getRect(found);
    return rect.top >= 0 && rect.bottom <= 914 * 0.72;
  }

  testWidgets('the 27th of 30 is on screen without scrolling', (tester) async {
    await open(tester, current: 27);

    expect(onScreen(tester, 'Song 27'), isTrue);
    // With the one before it, so it reads as a place in the list.
    expect(onScreen(tester, 'Song 26'), isTrue);
  });

  testWidgets('the first song opens at the top, as before', (tester) async {
    await open(tester, current: 0);

    expect(onScreen(tester, 'Song 0'), isTrue);
  });

  testWidgets('nested under the portrait video it does not move — that '
      'would move the page', (tester) async {
    await open(tester, current: 27, nested: true);

    expect(onScreen(tester, 'Song 0'), isTrue);
  });
}
