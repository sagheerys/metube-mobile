import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'fake_player_port.dart';

/// **Tablet guards, batch 2 (2026-10-10)**: the player panel beside the
/// library, its two tabs, and the full player's tablet forms. A phone keeps
/// the queue and the extra as buttons that open sheets.
void main() {
  late MemoryKeyValueStore store;
  late MTAudioHandler handler;

  setUp(() {
    store = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    handler = MTAudioHandler(
      player: FakePlayerPort(),
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint(
          buildUrl: (name) => 'https://srv/download/$name',
          headers: const {},
        ),
        fileExists: (_) => false,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
    );
  });
  tearDown(() => handler.dispose());

  PlaylistItem clip(String id) => PlaylistItem(
    canonicalUrl: 'https://x/$id',
    title: id,
    serverFilename: '$id.mp3',
    isAudio: true,
  );

  MTVideoPanel transcript(PlaylistItem item) => MTVideoPanel(
    icon: Icons.subject_rounded,
    label: 'Transcript',
    builder: (context, close) => Text('words of ${item.title}'),
  );

  Future<void> pump(WidgetTester tester, Size size, Widget child) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: child,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('the tabs', () {
    Widget tabs({bool companion = true}) => Scaffold(
      body: MTNowPlayingTabs(
        handler: handler,
        companion: companion ? transcript : null,
      ),
    );

    testWidgets('the companion opens first, and the queue is a tap away', (
      tester,
    ) async {
      await tester.runAsync(() => handler.playItems([clip('a'), clip('b')]));
      await pump(tester, const Size(400, 800), tabs());
      expect(find.text('words of a'), findsOneWidget);
      await tester.tap(find.textContaining('Up next'));
      await tester.pump();
      expect(find.text('words of a'), findsNothing);
      expect(find.byType(MTUpNextList), findsOneWidget);
    });

    testWidgets('with no companion the queue is the only tab', (tester) async {
      await tester.runAsync(() => handler.playItems([clip('a'), clip('b')]));
      await pump(tester, const Size(400, 800), tabs(companion: false));
      expect(find.text('Transcript'), findsNothing);
      expect(find.byType(MTUpNextList), findsOneWidget);
    });
  });

  group('the panel', () {
    Widget panel(void Function() onCollapse) => Scaffold(
      body: SizedBox(
        width: MTBreakpoint.sidePanel,
        child: MTNowPlayingPanel(
          handler: handler,
          onOpen: () {},
          onCollapse: onCollapse,
          companion: transcript,
        ),
      ),
    );

    testWidgets('is empty while nothing plays', (tester) async {
      await pump(tester, const Size(1280, 800), panel(() {}));
      expect(find.byType(MTPlayerControlsRow), findsNothing);
    });

    testWidgets('shows the controls and the transcript, and folds away', (
      tester,
    ) async {
      var folded = 0;
      await tester.runAsync(() => handler.playItems([clip('a'), clip('b')]));
      await pump(tester, const Size(1280, 800), panel(() => folded++));
      expect(find.byType(MTPlayerControlsRow), findsOneWidget);
      expect(find.text('words of a'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_fullscreen_rounded));
      expect(folded, 1);
    });

    testWidgets('fits a small tablet on its side at a large font', (
      tester,
    ) async {
      await tester.runAsync(() => handler.playItems([clip('a'), clip('b')]));
      for (final size in const [Size(960, 600), Size(1280, 800)]) {
        await pump(
          tester,
          size,
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: panel(() {}),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });
  });

  group('the full audio screen', () {
    Widget screen() =>
        MTAudioScreen(handler: handler, companion: transcript, extra: _extra);

    testWidgets('a phone keeps the queue and the extra as buttons', (
      tester,
    ) async {
      await tester.runAsync(() => handler.playItems([clip('a'), clip('b')]));
      await pump(tester, const Size(411, 914), screen());
      expect(find.byType(MTNowPlayingTabs), findsNothing);
      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('a tablet on its side puts the tabs in a second column', (
      tester,
    ) async {
      await tester.runAsync(() => handler.playItems([clip('a'), clip('b')]));
      await pump(tester, const Size(1280, 800), screen());
      final tabs = tester.getRect(find.byType(MTNowPlayingTabs));
      final controls = tester.getRect(find.byType(MTPlayerControlsRow));
      expect(tabs.left, greaterThan(controls.right));
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('an 8-inch tablet of 593 points on its side counts too', (
      tester,
    ) async {
      await tester.runAsync(() => handler.playItems([clip('a'), clip('b')]));
      await pump(tester, const Size(948, 593), screen());
      expect(find.byType(MTNowPlayingTabs), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tablet upright puts the tabs under the controls', (
      tester,
    ) async {
      await tester.runAsync(() => handler.playItems([clip('a'), clip('b')]));
      await pump(tester, const Size(800, 1280), screen());
      final tabs = tester.getRect(find.byType(MTNowPlayingTabs));
      final controls = tester.getRect(find.byType(MTPlayerControlsRow));
      expect(tabs.top, greaterThan(controls.bottom));
      expect(find.text('words of a'), findsOneWidget);
    });
  });

  group('the mini player', () {
    testWidgets('offers the panel back only when asked to', (tester) async {
      await tester.runAsync(() => handler.playItems([clip('a')]));
      await pump(
        tester,
        const Size(411, 914),
        Scaffold(
          bottomNavigationBar: MTMiniPlayer(handler: handler, onOpen: () {}),
        ),
      );
      expect(find.byIcon(Icons.open_in_full_rounded), findsNothing);

      var expanded = 0;
      await pump(
        tester,
        const Size(1280, 800),
        Scaffold(
          bottomNavigationBar: MTMiniPlayer(
            handler: handler,
            onOpen: () {},
            onExpand: () => expanded++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.open_in_full_rounded));
      expect(expanded, 1);
    });
  });
}

MTExtraAction? _extra(PlaylistItem item) =>
    MTExtraAction(icon: Icons.star, label: 'Extra', onTap: () {});
