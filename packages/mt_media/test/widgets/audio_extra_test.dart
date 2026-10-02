import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../playback/fake_player_port.dart';

/// The audio screen is shared: Super adds a transcript button beside
/// speed and queue, Lite adds nothing and must look as it always has.
void main() {
  late MTAudioHandler handler;

  setUp(() async {
    final store = MemoryKeyValueStore();
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
    await handler.playItems([
      const PlaylistItem(
        canonicalUrl: 'https://x/talk',
        title: 'A long talk',
        serverFilename: 'talk.mp3',
        isAudio: true,
      ),
    ]);
    await handler.pause();
  });
  tearDown(() => handler.dispose());

  MTExtraAction transcript({VoidCallback? onTap}) => MTExtraAction(
    icon: Icons.subject_rounded,
    label: 'Transcript',
    onTap: onTap ?? () {},
  );

  /// The screen on a phone of [size], without the source chip, which is
  /// not what these tests measure.
  Future<void> show(
    WidgetTester tester,
    MTExtraAction? Function(PlaylistItem item)? extra, {
    Size size = const Size(384, 823),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: MTAudioScreen(
            handler: handler,
            showSourceChip: false,
            extra: extra,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('without an extra, speed and queue alone', (tester) async {
    await show(tester, null);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.byIcon(Icons.subject_rounded), findsNothing);
  });

  testWidgets('an extra for the item playing shows, and answers a tap', (
    tester,
  ) async {
    final asked = <String>[];
    var taps = 0;
    await show(tester, (item) {
      asked.add(item.canonicalUrl);
      return transcript(onTap: () => taps++);
    });
    expect(asked, contains('https://x/talk'));
    expect(find.byTooltip('Transcript'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.subject_rounded));
    expect(taps, 1);
  });

  testWidgets('a null answer shows nothing', (tester) async {
    await show(tester, (_) => null);
    expect(find.byIcon(Icons.subject_rounded), findsNothing);
  });

  // The smallest phone at Android's largest text size: the screen used to
  // run past its bottom edge and its source chip past its side.
  testWidgets('holds on the smallest phone at the largest text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 534);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 534),
          textScaler: TextScaler.linear(2),
        ),
        child: MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: MTAudioScreen(handler: handler, extra: (_) => transcript()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  // A third pill adds no overflow where two fitted.
  for (final (size, scale) in const [
    (Size(360, 640), 1.0),
    (Size(360, 640), 1.3),
    (Size(384, 823), 1.0),
    (Size(384, 823), 1.3),
    (Size(411, 914), 1.3),
  ]) {
    testWidgets('a third pill fits ${size.width.round()} wide at ×$scale', (
      tester,
    ) async {
      await show(tester, (_) => null, size: size, scale: scale);
      expect(tester.takeException(), isNull, reason: 'two pills already');

      await show(tester, (_) => transcript(), size: size, scale: scale);
      expect(tester.takeException(), isNull);
    });
  }
}
