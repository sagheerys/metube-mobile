import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// The title under the video can be selected and copied, to look it up
/// elsewhere (owner's request 2026-11-11).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  testWidgets('**the guard**: the title under the video is selectable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 914) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    final session = MTVideoSession(
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => true,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
    );
    await tester.runAsync(
      () => session.open(const [
        PlaylistItem(
          canonicalUrl: 'https://x/a',
          title: 'Sourdough, Week 1 - The Starter',
          localPath: '/media/a.mp4',
        ),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.lite, Brightness.light),
        home: MTVideoScreen(session: session),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final sheetTitle = find.descendant(
      of: find.byType(MTVideoInfoSheet),
      matching: find.text('Sourdough, Week 1 - The Starter'),
    );
    expect(
      find.ancestor(of: sheetTitle, matching: find.byType(SelectionArea)),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(session.dispose);
  });
}
