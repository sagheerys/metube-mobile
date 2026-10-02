import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// Super adds a transcript beside the full-screen video; Lite adds nothing.
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

  Future<MTVideoSession> show(
    WidgetTester tester,
    MTVideoPanel? Function(PlaylistItem item)? panel,
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
        PlaylistItem(
          canonicalUrl: 'https://x/b',
          title: 'b',
          localPath: '/media/b.mp4',
        ),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: MTVideoFullscreenPage(session: session, panel: panel),
      ),
    );
    await settle(tester);
    return session;
  }

  Future<void> leave(WidgetTester tester, MTVideoSession session) async {
    // The chrome hides itself on a timer, so the tree goes first.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(session.dispose);
  }

  testWidgets('the panel opens beside the video and closes on request', (
    tester,
  ) async {
    late VoidCallback close;
    final session = await show(
      tester,
      (item) => MTVideoPanel(
        icon: Icons.subject_rounded,
        label: 'Transcript',
        builder: (context, onClose) {
          close = onClose;
          return Text('panel for ${item.title}');
        },
      ),
    );
    final controls = tester.widget<MTVideoControls>(
      find.byType(MTVideoControls),
    );
    expect(controls.extra, isNotNull);
    expect(find.text('panel for a'), findsNothing);

    controls.extra!.onTap();
    await settle(tester);
    expect(find.text('panel for a'), findsOneWidget);
    expect(find.byType(VideoPlayer), findsOneWidget, reason: 'still showing');

    close();
    await settle(tester);
    expect(find.text('panel for a'), findsNothing);
    await leave(tester, session);
  });

  testWidgets('the panel belongs to its clip: it closes when the next '
      'plays, and does not reopen by itself', (tester) async {
    final session = await show(
      tester,
      (item) => MTVideoPanel(
        icon: Icons.subject_rounded,
        label: 'Transcript',
        builder: (context, onClose) => Text('panel for ${item.title}'),
      ),
    );
    tester.widget<MTVideoControls>(find.byType(MTVideoControls)).extra!.onTap();
    await settle(tester);
    expect(find.text('panel for a'), findsOneWidget);

    await tester.runAsync(session.skipNext);
    await settle(tester);
    expect(find.text('panel for a'), findsNothing);
    expect(find.text('panel for b'), findsNothing);

    await tester.runAsync(() => session.jumpTo(0));
    await settle(tester);
    expect(find.textContaining('panel for'), findsNothing);
    await leave(tester, session);
  });

  testWidgets('without a panel there is no button', (tester) async {
    final session = await show(tester, null);
    final controls = tester.widget<MTVideoControls>(
      find.byType(MTVideoControls),
    );
    expect(controls.extra, isNull);
    await leave(tester, session);
  });
}
