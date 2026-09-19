import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **Field report 2026-09-19:** "in full screen, open the queue panel and
/// press 'view all' — the picture disappears, the clip keeps playing and
/// the phone stays sideways".
///
/// The callback pushed the playlists screen **over** the full-screen page,
/// which therefore stayed alive underneath: its `dispose` never ran, so the
/// immersive mode and the landscape lock it had installed went on ruling a
/// screen that wanted neither, with the video still playing behind it.
/// Full screen must be left first.
void main() {
  late List<List<String>> locks;

  bool isLandscapeLock(List<String> value) =>
      value.isNotEmpty &&
      value.every((o) => o.contains('landscape')) &&
      value.length == 2;

  setUp(() {
    locks = [];
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            locks.add(List<String>.from(call.arguments as List));
          }
          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('"view all" leaves full screen before the playlist opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final session = newSession();
    await tester.runAsync(
      () => session.open(const [
        PlaylistItem(
          canonicalUrl: 'https://x/a',
          title: 'a',
          localPath: '/media/a.mp4',
        ),
      ]),
    );

    var shown = 0;
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: const Scaffold(body: Center(child: Text('BASE'))),
      ),
    );
    unawaited(
      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => MTVideoFullscreenPage(
            session: session,
            playlistName: 'قائمتي',
            onShowPlaylist: () => shown++,
          ),
        ),
      ),
    );
    await settle(tester);
    expect(locks.last, predicate<List<String>>(isLandscapeLock));

    // The queue panel is a side panel opened from the controls, and the
    // actions are invoked directly rather than tapped: the chrome hides
    // itself on a timer, so a tap would be hostage to timing unrelated to
    // the guard.
    tester.widget<MTVideoControls>(find.byType(MTVideoControls)).onQueue();
    await settle(tester);
    final panel = tester.widget<MTQueuePanel>(find.byType(MTQueuePanel));
    panel.onShowAll!();
    await settle(tester);

    expect(
      find.byType(MTVideoFullscreenPage),
      findsNothing,
      reason: 'the page used to stay alive under the playlists screen',
    );
    expect(shown, 1, reason: 'and the playlist is still opened, once');
    expect(
      locks.last,
      isNot(predicate<List<String>>(isLandscapeLock)),
      reason: 'dispose ran, so the landscape lock was released',
    );
    await tester.runAsync(session.dispose);
  });

  testWidgets('with no playlist behind it the action is not offered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final session = newSession();
    await tester.runAsync(
      () => session.open(const [
        PlaylistItem(
          canonicalUrl: 'https://x/a',
          title: 'a',
          localPath: '/media/a.mp4',
        ),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: MTVideoFullscreenPage(session: session),
      ),
    );
    await settle(tester);

    tester.widget<MTVideoControls>(find.byType(MTVideoControls)).onQueue();
    await settle(tester);
    final panel = tester.widget<MTQueuePanel>(find.byType(MTQueuePanel));
    expect(panel.onShowAll, isNull);

    // The chrome hides itself on a timer, so the tree goes before the test
    // does.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(session.dispose);
  });
}
