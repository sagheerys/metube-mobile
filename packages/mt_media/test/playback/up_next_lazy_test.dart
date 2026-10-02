import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **Field report 2026-09-30:** the portrait player stuttered and its
/// controls were slow to show with the whole library (468 clips) as the
/// queue, and ran smoothly with a single clip. The "up next" rows were
/// built all at once, covers included, and built again on every tick of
/// the video's clock.
void main() {
  setUp(() {
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  const count = 468;
  final items = [
    for (var i = 0; i < count; i++)
      PlaylistItem(
        canonicalUrl: 'https://x/$i',
        title: 'clip number $i',
        localPath: '/media/$i.mp4',
      ),
  ];

  MTVideoSession newSession() {
    final store = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    return MTVideoSession(
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => true,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
    );
  }

  Widget app(Widget home) => MaterialApp(
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    home: home,
  );

  int rowsBuilt(WidgetTester tester) => find
      .textContaining('clip number ', skipOffstage: false)
      .evaluate()
      .length;

  testWidgets('under the portrait video, only the rows on screen are built', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 2.8;
    addTearDown(tester.view.reset);
    final session = newSession();
    await tester.runAsync(() => session.open(items));

    await tester.pumpWidget(
      app(Scaffold(body: MTVideoInfoSheet(session: session))),
    );
    await tester.pump();
    // The title of the clip playing is shown once above the list too.
    expect(rowsBuilt(tester), lessThan(40));

    // Still scrolls to the end: laziness must not cut the list short.
    await tester.dragUntilVisible(
      find.text('clip number ${count - 1}'),
      find.byType(Scrollable).first,
      const Offset(0, -3000),
      maxIteration: 200,
    );
    expect(find.text('clip number ${count - 1}'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(session.dispose);
  });

  // Bounded by the sheet, this one was always lazy; kept so it stays so.
  testWidgets('the queue sheet builds only what it shows', (tester) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 2.8;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMTQueueSheet(
                context,
                items: items,
                currentIndex: 0,
                onSelect: (_) {},
                // Still, so the equaliser does not keep the frames coming.
                paused: () => true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(rowsBuilt(tester), lessThan(40));
  });

  testWidgets('a short queue still sizes to its rows', (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMTQueueSheet(
                context,
                items: items.take(2).toList(),
                currentIndex: 0,
                onSelect: (_) {},
                // Still, so the equaliser does not keep the frames coming.
                paused: () => true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final sheet = tester.getSize(find.byType(MTQueuePanel));
    expect(sheet.height, lessThan(300));
  });
}
