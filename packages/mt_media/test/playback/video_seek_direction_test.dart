import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **Media time runs left to right in every language** (field report
/// 2026-09-25).
///
/// In Arabic the progress bar used to fill from the right while the
/// transport buttons stayed left to right, so a song moved leftwards and
/// "next" pointed right — read as reversed. Samsung Music, the system
/// media buttons and every car keep the whole timeline left to right; so
/// does this app now, in both players.
void main() {
  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlatform());

  Widget app(Locale locale, Widget child) => MaterialApp(
    locale: locale,
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    theme: mtTheme(MTVariant.superApp, Brightness.dark),
    home: Scaffold(body: Center(child: child)),
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

  for (final locale in const [Locale('ar'), Locale('en')]) {
    group('in ${locale.languageCode}', () {
      testWidgets('the video rewind button is on the left', (tester) async {
        final session = newSession();
        await tester.pumpWidget(
          app(locale, MTVideoCenterControls(session: session)),
        );
        await tester.pump();
        final rewind = tester
            .getCenter(find.byIcon(Icons.replay_10_rounded))
            .dx;
        final forward = tester
            .getCenter(find.byIcon(Icons.forward_10_rounded))
            .dx;
        // Closed inside the test: its save timer would outlive it.
        await tester.pumpWidget(const SizedBox());
        await session.dispose();

        expect(rewind, lessThan(forward));
      });

      testWidgets('the progress bar fills from the left: the elapsed time '
          'is on the left, and the left end is the start', (tester) async {
        Duration? sought;
        await tester.pumpWidget(
          app(
            locale,
            SizedBox(
              width: 360,
              child: MTProgressSlider(
                position: const Duration(seconds: 30),
                duration: const Duration(minutes: 3),
                onSeek: (to) => sought = to,
              ),
            ),
          ),
        );

        final elapsed = tester.getCenter(find.text('0:30')).dx;
        final remaining = tester.getCenter(find.text(mtLtrRun('-2:30'))).dx;
        expect(elapsed, lessThan(remaining));

        // A tap near the left end seeks near the start.
        final bar = tester.getRect(find.byType(Slider));
        await tester.tapAt(Offset(bar.left + bar.width * 0.1, bar.center.dy));
        await tester.pumpAndSettle();
        expect(sought, isNotNull);
        expect(sought!, lessThan(const Duration(minutes: 1)));
      });
    });
  }
}
