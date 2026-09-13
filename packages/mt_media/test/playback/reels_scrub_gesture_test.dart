import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **Field report 2026-09-13:** "pressing the reels counter to seek forward
/// or back pauses the video".
///
/// The bar's touch strip was 24 points and everything around it belongs to
/// tap-to-pause, so a finger that slightly missed it (just above the line,
/// in the system inset below it, or in the side margin) paused the clip a
/// moment later, and the bar took the blame.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlatform platform;

  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  const width = 411.0;
  const height = 914.0;

  /// A three-button navigation bar, the case the owner's gesture phone never
  /// shows.
  const inset = 48.0;

  Widget host() => MaterialApp(
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    home: MTReelsPlayer(
      lane: ShortsLane.from([
        const PlaylistItem(
          canonicalUrl: 'https://x/a',
          title: 'a',
          localPath: '/media/a.mp4',
          duration: Duration(seconds: 30),
          aspectRatio: 0.5625,
        ),
      ]),
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => true,
      ),
    ),
  );

  Future<void> load(WidgetTester tester) async {
    tester.view.physicalSize = const Size(width, height);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: inset);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.pump(); // postFrameCallback ⇒ _load
    await tester.pumpAndSettle();
    expect(platform.playing, hasLength(1), reason: 'the reel plays first');
  }

  /// A single tap on the picture only resolves once the double-tap window
  /// has passed, so the wait is part of the gesture.
  Future<void> tapAndWait(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
  }

  /// Releasing the player is asynchronous; see reels_lifecycle_test.dart.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  // The visible line sits about 72 points above the bottom edge here.
  for (final (where, point) in [
    ('just above the line', const Offset(width / 2, height - 90)),
    ('in the system inset below it', const Offset(width / 2, height - 20)),
    ('in the side margin', const Offset(8, height - 72)),
  ]) {
    testWidgets('a touch $where belongs to the bar and does not pause', (
      tester,
    ) async {
      await load(tester);
      await tapAndWait(tester, point);
      expect(platform.playing, hasLength(1), reason: 'the owner report');
      await finish(tester);
    });
  }

  testWidgets('a tap on the picture still pauses', (tester) async {
    await load(tester);
    await tapAndWait(tester, const Offset(width / 2, height / 2));
    expect(platform.playing, isEmpty);
    await finish(tester);
  });
}
