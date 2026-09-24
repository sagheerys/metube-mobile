import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/playlists/playlists_providers.dart';
import 'package:mt_core/mt_core.dart';

/// **An open playlist shows what was just added or removed** (field report
/// 2026-09-25: both appeared only after the app was closed).
///
/// The view read the store directly, so nothing it depended on changed
/// when the add sheet refreshed the playlists list; the family kept its
/// first answer for the whole run. Each test replays exactly what the
/// screens do after a change — refresh the list — and reads the view.
void main() {
  late ProviderContainer container;

  LibraryItem item(String url) =>
      LibraryItem(canonicalUrl: url, title: url, onServer: true);

  setUp(() {
    final kv = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(kv),
        prefsMutexProvider.overrideWithValue(mutex),
        // Without the auto-backup hook, which needs the whole app.
        playlistsStoreProvider.overrideWithValue(
          PlaylistsStore(store: kv, mutex: mutex),
        ),
        libraryItemsProvider.overrideWith(
          (ref) async => [item('https://v/1'), item('https://v/2')],
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<List<String>> shown(String id) async => [
    for (final entry in (await container.read(
      playlistViewProvider(id).future,
    )).items)
      entry.canonicalUrl,
  ];

  test(
    'a clip added while the playlist was already read shows at once',
    () async {
      final store = container.read(playlistsStoreProvider);
      final playlist = await store.create(
        'Drive',
        items: [toPlaylistEntry(item('https://v/1'))],
      );
      expect(await shown(playlist.id), ['https://v/1']);

      // What the add sheet does.
      await store.addItems(playlist.id, [toPlaylistEntry(item('https://v/2'))]);
      container
        ..invalidate(playlistsProvider)
        ..invalidate(playlistItemsProvider(playlist.id));

      expect(await shown(playlist.id), ['https://v/1', 'https://v/2']);
    },
  );

  test('a clip removed disappears at once', () async {
    final store = container.read(playlistsStoreProvider);
    final playlist = await store.create(
      'Drive',
      items: [
        toPlaylistEntry(item('https://v/1')),
        toPlaylistEntry(item('https://v/2')),
      ],
    );
    expect(await shown(playlist.id), hasLength(2));

    // What the details screen does.
    await store.removeItem(playlist.id, 'https://v/1');
    container
      ..invalidate(playlistItemsProvider(playlist.id))
      ..invalidate(playlistsProvider);

    expect(await shown(playlist.id), ['https://v/2']);
  });
}
