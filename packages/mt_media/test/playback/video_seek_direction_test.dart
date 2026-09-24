import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **The video's rewind and forward buttons sit the way its timeline runs**
/// (field report 2026-09-25: in Arabic they were reversed).
///
/// In Arabic the progress bar fills from the right and a double tap on the
/// right half goes back. The buttons were pinned left to right, so rewind
/// sat on the left, against both. They now follow the language.
void main() {
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

  Future<(double rewind, double forward)> positions(
    WidgetTester tester,
    Locale locale,
  ) async {
    final session = newSession();
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.dark),
        home: Scaffold(body: MTVideoCenterControls(session: session)),
      ),
    );
    await tester.pump();
    final found = (
      tester.getCenter(find.byIcon(Icons.replay_10_rounded)).dx,
      tester.getCenter(find.byIcon(Icons.forward_10_rounded)).dx,
    );
    // Closed inside the test: its save timer would otherwise outlive it.
    await tester.pumpWidget(const SizedBox());
    await session.dispose();
    return found;
  }

  testWidgets('in Arabic, rewind is on the right, where the timeline starts', (
    tester,
  ) async {
    final (rewind, forward) = await positions(tester, const Locale('ar'));

    expect(rewind, greaterThan(forward));
  });

  testWidgets('in English, rewind is on the left, as it always was', (
    tester,
  ) async {
    final (rewind, forward) = await positions(tester, const Locale('en'));

    expect(rewind, lessThan(forward));
  });
}
