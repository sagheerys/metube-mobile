import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/clip/clip_page.dart';
import 'package:metube_desktop/features/library/library_page.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/mini_window.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'support/shell_harness.dart';

void main() {
  Future<ShellHarness> open(
    WidgetTester tester, {
    PlaylistItem? playing,
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
      library: const [],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    // Paused: a running clip's equalizer never lets the test settle.
    if (playing != null) h.player.showPlaying([playing], playing: false);
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  final song = clip('Night Drive');
  const video = PlaylistItem(
    canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
    title: 'Homelab Hour',
    uploader: 'Field Notes',
  );

  testWidgets('**the guard**: Ctrl+M makes the window the small card sized '
      'for sound, above the others, and again brings the full one back', (
    tester,
  ) async {
    final h = await open(tester, playing: song);
    await ctrl(tester, LogicalKeyboardKey.keyM);
    expect(h.controls.calls, contains('mini 360x96'));
    // The sound strip keeps its one size.
    expect(h.controls.stretchable, isFalse);
    expect(find.byType(EmberMiniWindow), findsOneWidget);
    expect(find.byType(LibraryPage), findsNothing);

    await ctrl(tester, LogicalKeyboardKey.keyM);
    expect(h.controls.calls.last, 'mini off');
    expect(find.byType(LibraryPage), findsOneWidget);
  });

  testWidgets('**the guard**: a video takes the picture size', (tester) async {
    final h = await open(tester, playing: video);
    await ctrl(tester, LogicalKeyboardKey.keyM);
    expect(h.controls.calls, contains('mini 360x203'));
    // Owner's request 2026-11-10: the picture can be dragged larger by its
    // edges; it used to be locked at one size.
    expect(h.controls.stretchable, isTrue);
  });

  testWidgets('**the guard**: the small card answers only its own keys; Esc '
      'and a double click bring the full window back', (tester) async {
    final h = await open(tester, playing: song);
    await ctrl(tester, LogicalKeyboardKey.keyM);
    // Search wants the full window.
    await ctrl(tester, LogicalKeyboardKey.keyF);
    expect(find.byType(EmberMiniWindow), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(h.controls.calls.last, 'mini off');

    await ctrl(tester, LogicalKeyboardKey.keyM);
    await tester.tap(find.byType(EmberMiniWindow));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.byType(EmberMiniWindow));
    await tester.pumpAndSettle();
    expect(h.controls.calls.last, 'mini off');
  });

  for (final arabic in [false, true]) {
    testWidgets('**the guard**: the card and full screen take the maximize '
        "button's place away, so the card's next is not the window's "
        'maximize${arabic ? ', in Arabic' : ''}', (tester) async {
      if (arabic) ShellHarness.useArabic(tester);
      final h = await open(tester, playing: song);
      expect(h.controls.maximizeButton?.isEmpty, isFalse);

      await ctrl(tester, LogicalKeyboardKey.keyM);
      expect(h.controls.maximizeButton, Rect.zero);
      await ctrl(tester, LogicalKeyboardKey.keyM);
      expect(h.controls.maximizeButton?.isEmpty, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pumpAndSettle();
      expect(h.controls.maximizeButton, Rect.zero);
    });
  }

  testWidgets('the player bar offers it once something plays', (tester) async {
    final h = await open(tester);
    await tester.tap(byLabel('Small window'));
    await tester.pumpAndSettle();
    expect(h.controls.calls.where((c) => c.startsWith('mini')), isEmpty);

    h.player.showPlaying([song], playing: false);
    await tester.pumpAndSettle();
    await tester.tap(byLabel('Small window'));
    await tester.pumpAndSettle();
    expect(h.controls.calls, contains('mini 360x96'));
  });

  for (final arabic in [false, true]) {
    for (final (item, size) in [
      (song, EmberMiniSize.audio),
      (video, EmberMiniSize.video),
    ]) {
      testWidgets(
        'the card fits its window, ${item.isAudio ? 'sound' : 'picture'}'
        '${arabic ? ', in Arabic' : ''}, at twice the text too',
        (tester) async {
          if (arabic) ShellHarness.useArabic(tester);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await open(tester, playing: item);
          await ctrl(tester, LogicalKeyboardKey.keyM);
          for (final scale in [1.0, 2.0]) {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            ShellHarness.useWindow(tester, size);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'text x$scale');
          }
        },
      );
    }
  }

  testWidgets('**the guard**: back from the card after a next, the page is '
      "the clip playing now, not the last one's frozen cover", (tester) async {
    const next = PlaylistItem(
      canonicalUrl: 'https://youtu.be/bbbbbbbbbbb',
      title: 'Second Episode',
      uploader: 'Field Notes',
    );
    final h = await open(tester, playing: video);
    GoRouter.of(tester.element(find.byType(LibraryPage)))
        .go(EmberRoutes.item(video.canonicalUrl));
    await tester.pumpAndSettle();
    await ctrl(tester, LogicalKeyboardKey.keyM);
    // The card's next: the player moves on while the page is not there.
    h.player.showPlaying([next], playing: false);
    await tester.pumpAndSettle();
    await ctrl(tester, LogicalKeyboardKey.keyM);
    expect(
      tester.widget<ClipPage>(find.byType(ClipPage)).canonicalUrl,
      next.canonicalUrl,
    );
  });

  testWidgets('back from the card on another page, that page stays', (
    tester,
  ) async {
    const next = PlaylistItem(
      canonicalUrl: 'https://youtu.be/bbbbbbbbbbb',
      title: 'Second Episode',
    );
    final h = await open(tester, playing: video);
    await ctrl(tester, LogicalKeyboardKey.keyM);
    h.player.showPlaying([next], playing: false);
    await tester.pumpAndSettle();
    await ctrl(tester, LogicalKeyboardKey.keyM);
    expect(find.byType(LibraryPage), findsOneWidget);
    expect(find.byType(ClipPage), findsNothing);
  });
}
