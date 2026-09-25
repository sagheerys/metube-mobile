import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/playlists/playlist_details_screen.dart';
import 'package:metube_super/features/playlists/playlists_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'playback_test_doubles.dart';

/// **Playing a clip low in a playlist keeps the list where it was** (field
/// report 2026-09-25: it flashed and jumped to the top).
///
/// Playing records "last played" and refreshes the playlists list; the
/// playlist's view reads that list (so that adding and removing show at
/// once), and its reload used to swap the list for a spinner.
void main() {
  late MemoryKeyValueStore kv;
  late PrefsMutex mutex;
  late MTAudioHandler handler;

  // Outside the test body: the handler starts a periodic save timer in its
  // constructor, and one created inside the test's fake clock outlives it.
  setUp(() {
    kv = MemoryKeyValueStore();
    mutex = PrefsMutex();
    handler = MTAudioHandler(
      player: FakeMediaPlayer(),
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => false,
      ),
      positions: PlaybackPositionStore(store: kv, mutex: mutex),
      prefs: PlaybackPrefs(store: kv, mutex: mutex),
      stateStore: AudioStateStore(store: kv, mutex: mutex),
      saveInterval: const Duration(hours: 1),
    );
  });

  tearDown(() => handler.dispose());

  testWidgets('a reload of the playlists does not move the open playlist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = PlaylistsStore(store: kv, mutex: mutex);
    final items = [
      for (var i = 0; i < 30; i++)
        LibraryItem(
          canonicalUrl: 'https://v/$i',
          title: 'Song $i',
          onServer: true,
        ),
    ];
    final playlist = await store.create(
      'Drive',
      items: [for (final item in items) toPlaylistEntry(item)],
    );
    final container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
        keyValueStoreProvider.overrideWithValue(kv),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(mutex),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        playlistsStoreProvider.overrideWithValue(store),
        libraryItemsProvider.overrideWith((ref) async => items),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: PlaylistDetailsScreen(playlistId: playlist.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    final scrolled = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(scrolled, greaterThan(0));

    // What playing a clip does.
    await store.touchLastPlayed(playlist.id);
    container.invalidate(playlistsProvider);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();

    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      scrolled,
    );
  });
}
