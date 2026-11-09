import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/stats/library_stats_screen.dart';
import 'package:metube_super/features/stats/stats_parts.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Guard: «Your library»** (mobile plan, stage 16/F): the library
/// counted by site, channel and month, and what was never played, from
/// Settings. It counts and never deletes; a site opens the library
/// filtered to it.
void main() {
  const mb = 1024 * 1024;
  LibraryItem clip(
    String id, {
    String site = 'https://youtu.be/',
    String? channel,
    int size = 10,
    DateTime? added,
  }) => LibraryItem(
    canonicalUrl: '$site$id',
    title: 'Clip $id',
    uploader: channel,
    onServer: true,
    serverFilename: '$id.mp4',
    sizeBytes: size * mb,
    duration: const Duration(minutes: 30),
    timestamp: added ?? DateTime(2026, 10, 1),
  );

  final library = [
    clip('aaaaaaaaaaa', channel: 'Rivers', size: 300),
    clip('bbbbbbbbbbb', channel: 'Rivers', added: DateTime(2026, 9, 3)),
    clip('ccccccccccc', channel: 'Hills', size: 900),
    clip('ddd', site: 'https://www.tiktok.com/@a/video/', size: 50),
  ];

  late ProviderContainer container;

  Widget host() {
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          const SuperSettings(activeUrl: 'http://nas.local:8081'),
        ),
        libraryItemsProvider.overrideWith((ref) async => library),
      ],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        locale: const Locale('en'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: '/stats',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Text('LIBRARY')),
            GoRoute(
              path: '/stats',
              builder: (_, _) => const LibraryStatsScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('**the guard**: the library in figures, by site and channel, '
      'and what was never played', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await settle(tester);
    expect(find.text('Your library'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('By site'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('By channel'), findsOneWidget);
    expect(find.text('Rivers'), findsOneWidget);
    // Two months, as columns.
    expect(find.byType(StatsMonths), findsOneWidget);
    // Nothing was played here: the largest comes first.
    expect(find.textContaining('Never played here'), findsOneWidget);
    final first = tester.getTopLeft(find.text('Clip ccccccccccc'));
    final second = tester.getTopLeft(find.text('Clip aaaaaaaaaaa'));
    expect(first.dy, lessThan(second.dy));
  });

  testWidgets('a library refresh keeps the page and where it was read', (
    tester,
  ) async {
    // Defect: every refresh swapped the page for a spinner, so it flickered
    // and a reader scrolled down was thrown back to the top.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 700);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await settle(tester);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(200);
    await tester.pump();

    container.invalidate(libraryItemsProvider);
    await tester.pump();
    expect(find.byType(MTSpinner), findsNothing);
    expect(find.text('By site'), findsOneWidget);
    await settle(tester);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      200,
    );
  });

  testWidgets('a site opens the library filtered to it', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await settle(tester);
    await tester.tap(find.text('TikTok'));
    await settle(tester);
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(container.read(libraryViewProvider).platform, MediaPlatform.tiktok);
  });

  testWidgets('the page holds on every device and text scale', (tester) async {
    await expectNoOverflow(tester, host);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
