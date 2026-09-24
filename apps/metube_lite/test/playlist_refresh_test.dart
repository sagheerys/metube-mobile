import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/library_providers.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:metube_lite/features/playlists/playlists_providers.dart';
import 'package:mt_core/mt_core.dart';

/// **An open playlist shows what was just added or removed** (field report
/// 2026-09-25): the same fault, and the same fix, as in Super.
void main() {
  late ProviderContainer container;

  LocalItem clip(String name) => LocalItem(
    key: 'https://v/$name',
    path: '/music/$name.m4a',
    title: name,
    sizeBytes: 1,
    modified: DateTime(2026),
  );

  setUp(() {
    final kv = MemoryKeyValueStore();
    final mutex = PrefsMutex();
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(kv),
        prefsMutexProvider.overrideWithValue(mutex),
        playlistsStoreProvider.overrideWithValue(
          PlaylistsStore(store: kv, mutex: mutex),
        ),
        localMediaProvider.overrideWith((ref) async => [clip('a'), clip('b')]),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<int> shown(String id) async =>
      (await container.read(playlistViewProvider(id).future)).items.length;

  test('added and removed clips show at once', () async {
    final store = container.read(playlistsStoreProvider);
    final playlist = await store.create(
      'Drive',
      items: [toPlaylistEntry(clip('a'))],
    );
    expect(await shown(playlist.id), 1);

    await store.addItems(playlist.id, [toPlaylistEntry(clip('b'))]);
    container
      ..invalidate(playlistsProvider)
      ..invalidate(playlistItemsProvider(playlist.id));
    expect(await shown(playlist.id), 2);

    await store.removeItem(playlist.id, 'https://v/a');
    container
      ..invalidate(playlistItemsProvider(playlist.id))
      ..invalidate(playlistsProvider);
    expect(await shown(playlist.id), 1);
  });
}
