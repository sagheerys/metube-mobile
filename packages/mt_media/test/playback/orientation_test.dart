import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **Rotation guards (decision 2026-09-05)**: the app is portrait and only
/// the player rotates, and a tilt opens full screen and closes it.
///
/// The original defect: full screen's `dispose` locked `portraitUp`
/// **across the whole app and forever** (the call is global and does not
/// belong to the screen that made it), so after the first full-screen video
/// nothing rotated until the app was killed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<List<String>> locks;

  setUp(() {
    locks = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            locks.add(List<String>.from(call.arguments as List));
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  bool isPortraitLock(List<String> lock) =>
      lock.length == 1 && lock.single.endsWith('portraitUp');
  bool isLandscapeLock(List<String> lock) =>
      lock.length == 2 && lock.every((o) => o.contains('landscape'));
  bool isFree(List<String> lock) => lock.length == 3;

  /// A host that controls the orientation through the screen size, from
  /// which `Orientation` is derived.
  Widget host({required Size size, required Widget child}) => MediaQuery(
    data: MediaQueryData(size: size),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => child),
      ),
    ),
  );

  const portrait = Size(400, 800);
  const landscape = Size(800, 400);

  group('MTRotationScope', () {
    testWidgets('tilting the device opens fullscreen once', (tester) async {
      var opened = 0;
      Widget scope(Size size) => host(
        size: size,
        child: MTRotationScope(
          open: (byRotation) async {
            opened++;
            expect(byRotation, isTrue);
          },
          builder: (_, _) => const SizedBox.shrink(),
        ),
      );

      await tester.pumpWidget(scope(portrait));
      expect(opened, 0);

      await tester.pumpWidget(scope(landscape));
      await tester.pump();
      expect(opened, 1);

      // Extra frames in the same orientation open nothing new.
      await tester.pumpWidget(scope(landscape));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets(
      'leaving by hand while landscape does not reopen it immediately',
      (tester) async {
        var opened = 0;
        Widget scope(Size size) => host(
          size: size,
          child: MTRotationScope(
            // Full screen closed immediately, as if the user had pressed
            // exit.
            open: (_) async => opened++,
            builder: (_, _) => const SizedBox.shrink(),
          ),
        );

        await tester.pumpWidget(scope(landscape));
        await tester.pump();
        expect(opened, 1);

        // The loop this guards against: you exit, the scope sees a landscape
        // device and reopens, you exit, it reopens, endlessly.
        for (var i = 0; i < 3; i++) {
          await tester.pumpWidget(scope(landscape));
          await tester.pump();
        }
        expect(opened, 1);

        // Returning to portrait rearms it, and the next tilt opens again.
        await tester.pumpWidget(scope(portrait));
        await tester.pump();
        await tester.pumpWidget(scope(landscape));
        await tester.pump();
        expect(opened, 2);
      },
    );

    testWidgets(
      'the button opens without a tilt, and tells the page it was not a rotation',
      (tester) async {
        bool? byRotation;
        late VoidCallback press;
        await tester.pumpWidget(
          host(
            size: portrait,
            child: MTRotationScope(
              open: (r) async => byRotation = r,
              builder: (_, open) {
                press = open;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        press();
        await tester.pump();
        expect(byRotation, isFalse);
      },
    );

    testWidgets('it unlocks on entering and locks again on leaving', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          size: portrait,
          child: MTRotationScope(
            open: (_) async {},
            builder: (_, _) => const SizedBox.shrink(),
          ),
        ),
      );
      expect(
        locks.where(isFree).length,
        1,
        reason: 'المشغل مفتوح ⇒ التدوير مسموح',
      );

      // An entirely different tree: swapping `child` inside the same
      // `Navigator` does not rebuild its existing route, so the scope is
      // never disposed.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      // The guard: the lock returns when the player is left, not before and
      // not never.
      expect(locks.any(isPortraitLock), isTrue);
    });
  });

  group('MTOrientation', () {
    test('portrait alone does not include upside down', () {
      expect(MTOrientation.portrait, [DeviceOrientation.portraitUp]);
      expect(
        MTOrientation.free.contains(DeviceOrientation.portraitDown),
        isFalse,
      );
    });

    testWidgets('lockLandscape sends the two landscape orientations alone', (
      tester,
    ) async {
      await MTOrientation.lockLandscape();
      expect(locks.single, predicate<List<String>>(isLandscapeLock));
    });
  });

  group('the real player: the reported defect', () {
    setUp(() => VideoPlayerPlatform.instance = FakeVideoPlatform());

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
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('leaving fullscreen does not pin the app to portrait', (
      tester,
    ) async {
      // **A portrait test surface**: the default 800x600 is landscape, so
      // full screen opens on the tilt before we press the button, while it
      // is the button's path we are guarding.
      tester.view.physicalSize = const Size(1200, 2400);
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
            builder: (_) => MTVideoScreen(session: session),
          ),
        ),
      );
      await settle(tester);
      expect(
        locks.last,
        predicate<List<String>>(isFree),
        reason: 'المشغل مفتوح ⇒ الدوران مسموح',
      );

      // Entering by the button forces landscape, since someone with
      // rotation locked cannot tilt. The action is invoked directly rather
      // than by a tap: the chrome hides itself on a timer, so a tap becomes
      // hostage to timing unrelated to what is being guarded.
      tester
          .widget<MTVideoTopBar>(find.byType(MTVideoTopBar).first)
          .onToggleFullscreen();
      await settle(tester);
      expect(locks.last, predicate<List<String>>(isLandscapeLock));

      navKey.currentState!.pop();
      await settle(tester);
      // **The guard**: this used to be `portraitUp`, an app-wide command
      // that does not end when the page closes, so nothing rotated
      // afterwards until the app was killed.
      expect(locks.last, predicate<List<String>>(isFree));

      navKey.currentState!.pop();
      await settle(tester);
      expect(
        locks.last,
        predicate<List<String>>(isPortraitLock),
        reason: 'مغادرة المشغل ⇒ يعود قفل التطبيق الطولي',
      );
      await tester.runAsync(session.dispose);
    });
  });
}
