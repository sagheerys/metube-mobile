import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_media/src/video/reels_progress.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **The reels bar runs left to right in Arabic too** (2026-09-25).
///
/// The same day media time became left to right everywhere, the reels bar
/// got its drag and its row order pinned — but not the line itself:
/// LinearProgressIndicator paints by the ambient direction, not by its
/// Row's, so in Arabic it still filled from the right while the finger was
/// counted from the left. Instagram and YouTube keep it left to right.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlatform platform;

  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  const width = 411.0;
  const height = 914.0;

  Widget host() => MaterialApp(
    locale: const Locale('ar'),
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

  testWidgets('in Arabic, the line is painted left to right, and a drag near '
      'the left edge shows a fill near the start', (tester) async {
    tester.view.physicalSize = const Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pumpAndSettle();

    final line = find.descendant(
      of: find.byType(ReelsProgressBar),
      matching: find.byType(LinearProgressIndicator),
    );
    expect(Directionality.of(tester.element(line)), TextDirection.ltr);

    final bar = tester.getRect(find.byType(ReelsProgressBar));
    final gesture = await tester.startGesture(
      Offset(bar.left + bar.width * 0.1, bar.center.dy),
    );
    await gesture.moveBy(const Offset(12, 0));
    await tester.pump();
    final shown = tester.widget<LinearProgressIndicator>(line).value!;
    expect(shown, lessThan(0.3));
    await gesture.up();
    await tester.pump();

    // Releasing the player is asynchronous; see reels_lifecycle_test.dart.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  });
}
