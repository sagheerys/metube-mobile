import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **A transcript in the shorts (2026-10-14)**: the app follows the reel on
/// screen through a handle, and its button joins the side column, which
/// must still fit the smallest phone at the largest text.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlatform());

  const clip = PlaylistItem(
    canonicalUrl: 'https://x/a',
    title: 'a',
    localPath: '/media/a.mp4',
    duration: Duration(seconds: 30),
    aspectRatio: 0.5625,
  );

  Widget host(
    MTReelsHandle handle, {
    Locale locale = const Locale('en'),
    bool withActions = false,
  }) => MaterialApp(
    locale: locale,
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    theme: mtTheme(MTVariant.superApp, Brightness.dark),
    home: MTReelsPlayer(
      lane: ShortsLane.from([clip]),
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => true,
      ),
      handle: handle,
      isFavorite: (_) => false,
      onToggleFavorite: withActions ? (_) {} : null,
      actionsBuilder: withActions
          ? (_) => [
              for (final (icon, label) in const [
                (Icons.subject_rounded, 'Transcript'),
                (Icons.info_outline_rounded, 'Details'),
                (Icons.playlist_add_rounded, 'Add to…'),
                (Icons.download_rounded, 'Save to device'),
                (Icons.share_rounded, 'Share'),
              ])
                MTPlayerAction(icon: icon, label: label, onTap: () {}),
            ]
          : null,
    ),
  );

  testWidgets('the handle follows the reel while it lives, and not after', (
    tester,
  ) async {
    final handle = MTReelsHandle();
    expect(handle.current, isNull);
    await tester.pumpWidget(host(handle));
    await tester.pumpAndSettle();
    expect(handle.current?.canonicalUrl, clip.canonicalUrl);
    expect(handle.position, Duration.zero);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(handle.current, isNull);
    await handle.seek(const Duration(seconds: 3)); // harmless once closed
  });

  testWidgets('six buttons fit the side column on any phone and text size', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    for (final size in const [
      Size(320, 640),
      Size(360, 740),
      Size(384, 823),
      Size(411, 914),
    ]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final locale in const [Locale('en'), Locale('ar')]) {
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpWidget(
            host(MTReelsHandle(), locale: locale, withActions: true),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$size at $scale (${locale.languageCode})',
          );
          // Held from the bottom alone, the column climbed over the top
          // bar on small phones; it must stay below it.
          final rail = tester.getRect(find.byType(MTReelsRail));
          final bar = tester.getRect(find.byType(MTReelsTopBar));
          expect(
            rail.top,
            greaterThanOrEqualTo(bar.bottom),
            reason: 'over the top bar: $size at $scale',
          );
          // Where it fits, nothing moved: still 150 from the bottom.
          if (size == const Size(411, 914) && scale == 1.0) {
            expect(rail.bottom, size.height - 150);
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  });
}
