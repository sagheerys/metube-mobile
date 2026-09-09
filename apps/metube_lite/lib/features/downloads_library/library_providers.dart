import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show MediaShape;

import '../../di.dart';
import '../shared/async_view.dart';
import 'local_item.dart';

/// The local library: **scanning the folder** is the source. A file that
/// actually exists is shown, and the indexes only enrich it. That is how
/// files from the old Lite appear after migration, and how files deleted
/// from outside the app disappear with no ghosts.
final localMediaProvider = FutureProvider<List<LocalItem>>((ref) async {
  final offline = await ref.watch(offlineIndexProvider).readAll();
  final titles = await ref.watch(titleIndexProvider).readAll();
  final artwork = await ref.watch(artworkIndexProvider).readAll();
  final tags = await ref.watch(tagsIndexProvider).readAll();
  final Map<String, MediaShape> shapes = await ref
      .watch(mediaShapeIndexProvider)
      .readAll();

  // The offline index inverted (canonicalUrl to path) so every file's URL
  // is known.
  final urlOfPath = {
    for (final MapEntry(:key, :value) in offline.entries) value: key,
  };

  final dir = Directory(liteMediaDir);
  if (!await dir.exists()) return const [];

  final items = <LocalItem>[];
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File || !isMediaFile(entity.path)) continue;
    final path = entity.path.replaceAll(r'\', '/');
    final url = urlOfPath[path];
    final key = url ?? path;
    final stat = await entity.stat();
    final shape = shapes[key];
    items.add(
      LocalItem(
        key: key,
        path: path,
        canonicalUrl: url,
        title:
            titles[key] ??
            titles[path] ??
            LocalItem.titleFromFilename(path.split('/').last),
        sizeBytes: stat.size,
        modified: stat.modified,
        thumbnail: artwork[key] ?? artwork[path],
        favorite: (tags[key] ?? tags[path] ?? const []).contains(
          MTConstants.favoritesSystemTag,
        ),
        duration: shape?.duration,
        aspectRatio: shape?.aspectRatio,
      ),
    );
  }
  return items;
});

/// View options plus multi-select. Sorting and the view mode are saved.
class LibraryViewOptions {
  const LibraryViewOptions({
    this.scope = LocalScope.all,
    this.type = MediaTypeFilter.all,
    this.query = '',
    this.platform,
    this.sort = LibrarySort.newest,
    this.mode = LibraryViewMode.list,
    this.selection = const {},
  });

  final LocalScope scope;
  final MediaTypeFilter type;
  final String query;

  /// The platform filter with live counts (Lite specific).
  final MediaPlatform? platform;
  final LibrarySort sort;

  /// The saved view mode: one of four, not overlapping flags. Grid came
  /// over from Super on request 2026-09-04, and cards on 2026-09-08.
  final LibraryViewMode mode;

  bool get compact => mode == LibraryViewMode.compact;
  bool get grid => mode == LibraryViewMode.grid;
  bool get cards => mode == LibraryViewMode.cards;

  /// The selected item keys; a non-empty set means selection mode (rule 6).
  final Set<String> selection;

  bool get selecting => selection.isNotEmpty;

  LibraryViewOptions copyWith({
    LocalScope? scope,
    MediaTypeFilter? type,
    String? query,
    MediaPlatform? Function()? platform,
    LibrarySort? sort,
    LibraryViewMode? mode,
    Set<String>? selection,
  }) => LibraryViewOptions(
    scope: scope ?? this.scope,
    type: type ?? this.type,
    query: query ?? this.query,
    platform: platform == null ? this.platform : platform(),
    sort: sort ?? this.sort,
    mode: mode ?? this.mode,
    selection: selection ?? this.selection,
  );
}

class LibraryViewNotifier extends Notifier<LibraryViewOptions> {
  @override
  LibraryViewOptions build() {
    _restore();
    return const LibraryViewOptions();
  }

  Future<void> _restore() async {
    final store = ref.read(keyValueStoreProvider);
    final sortName = await store.getString('video_sort_option');
    state = state.copyWith(
      sort:
          LibrarySort.values.where((s) => s.name == sortName).firstOrNull ??
          LibrarySort.newest,
      mode: await _restoreMode(store),
    );
  }

  /// **A silent migration from the two old keys**: someone updating the app
  /// while on compact or grid must find their mode as they left it, not be
  /// thrown back to the list. The new key is written on the first change,
  /// and the old two are read when it is absent.
  Future<LibraryViewMode> _restoreMode(KeyValueStore store) async {
    final name = await store.getString('library_view_mode');
    final saved = LibraryViewMode.values
        .where((m) => m.name == name)
        .firstOrNull;
    if (saved != null) return saved;
    if (await store.getBool('library_grid_view') ?? false) {
      return LibraryViewMode.grid;
    }
    if (await store.getBool('library_compact_view') ?? false) {
      return LibraryViewMode.compact;
    }
    return LibraryViewMode.list;
  }

  void setScope(LocalScope scope) => state = state.copyWith(scope: scope);
  void setType(MediaTypeFilter type) => state = state.copyWith(type: type);
  void setQuery(String query) => state = state.copyWith(query: query);
  void setPlatform(MediaPlatform? platform) =>
      state = state.copyWith(platform: () => platform);

  Future<void> setSort(LibrarySort sort) async {
    state = state.copyWith(sort: sort);
    await ref
        .read(prefsMutexProvider)
        .run(
          () => ref
              .read(keyValueStoreProvider)
              .setString('video_sort_option', sort.name),
        );
  }

  Future<void> setMode(LibraryViewMode mode) async {
    state = state.copyWith(mode: mode);
    await ref
        .read(prefsMutexProvider)
        .run(
          () => ref
              .read(keyValueStoreProvider)
              .setString('library_view_mode', mode.name),
        );
  }

  void toggleSelected(String key) {
    final selection = Set<String>.from(state.selection);
    selection.contains(key) ? selection.remove(key) : selection.add(key);
    state = state.copyWith(selection: selection);
  }

  void selectAll(Iterable<String> keys) =>
      state = state.copyWith(selection: {...keys});

  void clearSelection() => state = state.copyWith(selection: const {});
}

final libraryViewProvider =
    NotifierProvider<LibraryViewNotifier, LibraryViewOptions>(
      LibraryViewNotifier.new,
    );

/// The list on screen after filtering and sorting.
///
/// **`whenData` was erasing the retained data** (field report 2026-09-03,
/// reproduced on Super with a screen recording: the library was replaced by
/// a spinner for 13 seconds during a single download). That function
/// dispatches on the **type** of the state rather than on whether a value
/// exists, so on `AsyncLoading` it returns a **new empty** instance, losing
/// whatever Riverpod held from before, and the ordering in the screen looks
/// to have no effect. Lite rescans the folder after every completion and
/// suffers the same thing.
///
/// The rule is now explicit: **a value exists, show it; else the error;
/// else loading.**
final visibleLibraryProvider = Provider<AsyncValue<List<LocalItem>>>((ref) {
  final options = ref.watch(libraryViewProvider);
  return asyncViewOf(
    ref.watch(localMediaProvider),
    (items) => buildLocalLibraryView(
      items,
      scope: options.scope,
      type: options.type,
      query: options.query,
      platform: options.platform,
      sort: options.sort,
    ),
  );
});

/// Platform chip counters, computed over the whole library rather than over
/// what is displayed, so the chip you tap does not vanish.
final platformCountsProvider = Provider<List<MapEntry<MediaPlatform, int>>>((
  ref,
) {
  final items = ref.watch(localMediaProvider).valueOrNull ?? const [];
  return platformCounts(items);
});

/// The item to highlight, from a tap on the completion notification
/// (`03-APP-FLOW.md` §1).
final highlightedItemProvider = StateProvider<String?>((ref) => null);
