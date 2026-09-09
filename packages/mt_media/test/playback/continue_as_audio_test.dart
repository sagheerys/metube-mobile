import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **A field regression reproduced on the emulator (2026-09-03).**
///
/// Field report: "on going back the continue-in-background message appears,
/// and pressing continue as audio starts the audio **and stays on the same
/// screen**… and stopping the clip in the mini player kills the app
/// entirely and shows a black screen".
///
/// The cause: `just_audio.play()`, in the package's own words, "completes
/// when playback ends or is stopped". Awaiting it hung the handover so the
/// screen never closed; then on stopping, the future completed and the
/// deferred `pop` ran, by which time the user had left, **so it popped the
/// shell itself**. Both ends are guarded here: a slow handover, and the
/// sanctity of somebody else's page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlatform platform;

  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

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

  const item = PlaylistItem(
    canonicalUrl: 'https://x/a',
    title: 'a',
    localPath: '/media/a.mp4',
  );

  /// **No `pumpAndSettle`**: the screen holds permanently animating
  /// indicators (the "now playing" equaliser), so it never settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// **A portrait test surface, like a phone.** The default 800x600 is
  /// *landscape*, and since 2026-09-05 the player opens full screen on a
  /// tilt, so these tests were starting inside full screen without meaning
  /// to.
  void usePhonePortrait(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> openPlayer(
    WidgetTester tester,
    GlobalKey<NavigatorState> navKey,
    MTVideoSession session,
    Future<void> Function(PlaylistItem, Duration) onContinueAsAudio,
  ) async {
    usePhonePortrait(tester);
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
          builder: (_) => MTVideoScreen(
            session: session,
            onContinueAsAudio: onContinueAsAudio,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('نقلٌ بطيء لا يُسقط الغلاف بعد أن يغادر المستخدم بطريق آخر', (
    tester,
  ) async {
    final session = newSession();
    await tester.runAsync(() => session.open([item]));
    final transfer = Completer<void>();
    final navKey = GlobalKey<NavigatorState>();
    await openPlayer(tester, navKey, session, (_, _) => transfer.future);

    // Going back opens the "continue in the background?" dialog, then
    // "continue as audio".
    unawaited(navKey.currentState!.maybePop());
    await settle(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('BASE'), findsNothing, reason: 'النقل لم يكتمل بعد');

    // The user leaves by themselves (the second press in the report).
    navKey.currentState!.pop();
    await settle(tester);
    expect(find.text('BASE'), findsOneWidget);

    // And then the handover completes late, when the audio is stopped in
    // the mini player.
    transfer.complete();
    await settle(tester);

    expect(
      find.text('BASE'),
      findsOneWidget,
      reason: 'pop عمياء كانت تُسقط الغلاف ⇒ شاشة سوداء',
    );
    await tester.runAsync(session.dispose);
  });

  testWidgets('النقل السريع يُغلق الشاشة كالمعتاد', (tester) async {
    final session = newSession();
    await tester.runAsync(() => session.open([item]));
    var transferred = 0;
    final navKey = GlobalKey<NavigatorState>();
    await openPlayer(tester, navKey, session, (_, _) async => transferred++);

    unawaited(navKey.currentState!.maybePop());
    await settle(tester);
    await tester.tap(find.byType(FilledButton));
    await settle(tester);

    expect(transferred, 1);
    expect(find.text('BASE'), findsOneWidget, reason: 'يجب أن تُغلق صفحتنا');
    await tester.runAsync(session.dispose);
  });

  testWidgets('«لا، أوقف» تُغلق الشاشة بلا نقل', (tester) async {
    final session = newSession();
    await tester.runAsync(() => session.open([item]));
    var transferred = 0;
    final navKey = GlobalKey<NavigatorState>();
    await openPlayer(tester, navKey, session, (_, _) async => transferred++);

    unawaited(navKey.currentState!.maybePop());
    await settle(tester);
    await tester.tap(find.byType(TextButton).last);
    await settle(tester);

    expect(transferred, 0);
    expect(find.text('BASE'), findsOneWidget);
    await tester.runAsync(session.dispose);
  });
}
