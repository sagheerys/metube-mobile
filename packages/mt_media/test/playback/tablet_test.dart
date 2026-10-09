import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **Tablet guards (2026-10-10)**: a large screen is never locked to
/// portrait, a tilt there is a way of holding it rather than a request for
/// full screen, and a tablet on its side shows the video and its details
/// together. Phones keep every rule they had, guarded in
/// `orientation_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<List<String>> locks;

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

  tearDown(() {
    MTOrientation.largeScreen = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  bool isPortraitLock(List<String> lock) =>
      lock.length == 1 && lock.single.endsWith('portraitUp');
  bool isFree(List<String> lock) => lock.length == 3;

  group('the resting orientation', () {
    test('a phone rests in portrait', () async {
      MTOrientation.largeScreen = false;
      await MTOrientation.home();
      expect(isPortraitLock(locks.single), isTrue);
    });

    test('a large screen rests free', () async {
      MTOrientation.largeScreen = true;
      await MTOrientation.home();
      expect(isFree(locks.single), isTrue);
    });

    testWidgets('a large display is detected after the first frame', (
      tester,
    ) async {
      // The test display is 800x600 points: its shorter side is 600.
      MTOrientation.start();
      await tester.pumpWidget(const SizedBox());
      expect(MTOrientation.largeScreen, isTrue);
      expect(isFree(locks.last), isTrue);
    });
  });

  group('the rotation scope on a large screen', () {
    Widget scope(Size size, void Function() onOpen) => MediaQuery(
      data: MediaQueryData(size: size),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => MTRotationScope(
              open: (_) async => onOpen(),
              builder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    testWidgets('holding a tablet sideways does not open full screen', (
      tester,
    ) async {
      MTOrientation.largeScreen = true;
      var opened = 0;
      await tester.pumpWidget(scope(const Size(800, 1280), () => opened++));
      await tester.pumpWidget(scope(const Size(1280, 800), () => opened++));
      await tester.pump();
      expect(opened, 0);
    });

    testWidgets('leaving the player does not lock a tablet to portrait', (
      tester,
    ) async {
      MTOrientation.largeScreen = true;
      await tester.pumpWidget(scope(const Size(1280, 800), () {}));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(locks.any(isPortraitLock), isFalse);
      expect(isFree(locks.last), isTrue);
    });
  });

  group('the video screen on a tablet held sideways', () {
    MTVideoSession newSession() => MTVideoSession(
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => true,
      ),
      positions: PlaybackPositionStore(
        store: MemoryKeyValueStore(),
        mutex: PrefsMutex(),
      ),
      prefs: PlaybackPrefs(store: MemoryKeyValueStore(), mutex: PrefsMutex()),
      saveInterval: const Duration(hours: 1),
    );

    Future<MTVideoSession> open(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = newSession();
      await tester.runAsync(
        () => session.open(const [
          PlaylistItem(
            canonicalUrl: 'https://x/a',
            title: 'مقطع',
            localPath: '/media/a.mp4',
          ),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          home: MTVideoScreen(session: session),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return session;
    }

    testWidgets('shows the details beside the video, not full screen', (
      tester,
    ) async {
      MTOrientation.largeScreen = true;
      final session = await open(tester, const Size(1280, 800));
      expect(find.byType(MTVideoFullscreenPage), findsNothing);
      final sheet = find.byType(MTVideoInfoSheet);
      expect(sheet, findsOneWidget);
      expect(tester.getSize(sheet).width, MTBreakpoint.sidePanel);
      await tester.pump(const Duration(seconds: 10));
      await tester.runAsync(session.dispose);
    });

    testWidgets('a phone on its side still gets the video alone', (
      tester,
    ) async {
      final session = await open(tester, const Size(914, 411));
      expect(
        find.byType(MTVideoInfoSheet, skipOffstage: false),
        findsNothing,
        reason: 'هاتف أفقي: الفيديو وحده، كما كان',
      );
      Navigator.of(tester.element(find.byType(MTVideoFullscreenPage))).pop();
      await tester.pump(const Duration(seconds: 10));
      await tester.runAsync(session.dispose);
    });
  });
}
