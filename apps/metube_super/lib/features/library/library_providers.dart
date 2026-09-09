import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show MediaShape;

import '../../di.dart';
import '../shared/async_view.dart';
import 'library_models.dart';

/// The unified library items: the server's done list plus the local index,
/// merged on canonicalUrl with fuzzy matching.
final libraryItemsProvider = FutureProvider<List<LibraryItem>>((ref) async {
  final history = await ref.watch(historyProvider.future);
  final offline = await ref.watch(offlineIndexProvider).readAll();
  final tags = await ref.watch(tagsIndexProvider).readAll();
  final artwork = await ref.watch(artworkIndexProvider).readAll();
  final Map<String, MediaShape> shapes = await ref
      .watch(mediaShapeIndexProvider)
      .readAll();

  List<String> userTags(String url) => [
    for (final t in tags[url] ?? const <String>[])
      if (t != MTConstants.favoritesSystemTag) t,
  ];
  bool isFavorite(String url) =>
      (tags[url] ?? const []).contains(MTConstants.favoritesSystemTag);

  final items = <LibraryItem>[];
  final matchedLocal = <String>{};

  final done = [
    for (final entry in history?.done ?? const <HistoryItem>[])
      if (entry.isCompleted) entry,
  ];

  // **Two passes rather than one** (defect found 2026-09-08): exact
  // matching first for **all** items, then fuzzy matching over what
  // remains. With a single pass, an earlier item takes by a fuzzy match a
  // key a later item owns exactly.
  final localOf = <String, String>{};
  for (final entry in done) {
    final exact = offline[entry.canonicalUrl];
    if (exact == null) continue;
    localOf[entry.canonicalUrl] = exact;
    matchedLocal.add(entry.canonicalUrl);
  }
  for (final entry in done) {
    if (localOf.containsKey(entry.canonicalUrl)) continue;
    for (final MapEntry(:key, :value) in offline.entries) {
      // **One file is never given to two items**: Facebook URLs all matched
      // each other (fixed in `UrlKit`), so the offline item's file appeared
      // under every Facebook item and opened in the external player in
      // their place. This bound makes the symptom impossible even if
      // another matching rule collides tomorrow.
      if (matchedLocal.contains(key)) continue;
      if (UrlKit.urlsMatch(key, entry.canonicalUrl)) {
        localOf[entry.canonicalUrl] = value;
        matchedLocal.add(key);
        break;
      }
    }
  }

  for (final entry in done) {
    final localPath = localOf[entry.canonicalUrl];
    final shape = shapes[entry.canonicalUrl];
    items.add(
      LibraryItem.fromHistory(
        entry,
        localPath: localPath,
        favorite: isFavorite(entry.canonicalUrl),
        tags: userTags(entry.canonicalUrl),
        duration: shape?.duration,
        aspectRatio: shape?.aspectRatio,
        cachedThumb: artwork[entry.canonicalUrl],
      ),
    );
  }

  // Local and no longer on the server, deleted there, but still in the
  // unified library.
  for (final MapEntry(:key, :value) in offline.entries) {
    if (matchedLocal.contains(key)) continue;
    items.add(
      LibraryItem.fromOfflineOnly(
        key,
        value,
        favorite: isFavorite(key),
        tags: userTags(key),
        cachedThumb: artwork[key],
        duration: shapes[key]?.duration,
        aspectRatio: shapes[key]?.aspectRatio,
      ),
    );
  }
  return items;
});

/// View options plus multi-select. Sorting and the view mode are saved.
class LibraryViewOptions {
  const LibraryViewOptions({
    this.scope = LibraryScope.all,
    this.type = MediaTypeFilter.all,
    this.query = '',
    this.tags = const {},
    this.excludedTags = const {},
    this.platform,
    this.sort = LibrarySort.newest,
    this.mode = LibraryViewMode.list,
    this.selection = const {},
  });

  final LibraryScope scope;
  final MediaTypeFilter type;
  final String query;

  /// Included tags (OR between them) and excluded ones: compound filtering
  /// with no extra screen.
  final Set<String> tags;
  final Set<String> excludedTags;

  /// **The platform filter** (requested 2026-09-08, as in Lite): it lives
  /// in the sort sheet rather than a third row of chips, because this
  /// library already has a filter row and a tag row above it and a third
  /// would push the first card off screen. The chosen platform appears as a
  /// removable chip in **the first row**.
  final MediaPlatform? platform;
  final LibrarySort sort;

  /// The saved view mode: one of four, not overlapping flags.
  final LibraryViewMode mode;

  bool get compact => mode == LibraryViewMode.compact;
  bool get grid => mode == LibraryViewMode.grid;
  bool get cards => mode == LibraryViewMode.cards;

  /// How many filters are active above "all", for the sort button's badge.
  final Set<String> selection;

  bool get selecting => selection.isNotEmpty;

  /// How many filters are active above "all", for the sort button's badge.
  int get activeFilters =>
      (scope == LibraryScope.all ? 0 : 1) +
      (type == MediaTypeFilter.all ? 0 : 1) +
      (platform == null ? 0 : 1) +
      tags.length +
      excludedTags.length;

  LibraryViewOptions copyWith({
    LibraryScope? scope,
    MediaTypeFilter? type,
    String? query,
    Set<String>? tags,
    Set<String>? excludedTags,
    MediaPlatform? Function()? platform,
    LibrarySort? sort,
    LibraryViewMode? mode,
    Set<String>? selection,
  }) => LibraryViewOptions(
    scope: scope ?? this.scope,
    type: type ?? this.type,
    query: query ?? this.query,
    tags: tags ?? this.tags,
    excludedTags: excludedTags ?? this.excludedTags,
    // A function rather than a value: `null` means "no change" for
    // every other field, and here `null` is a valid value meaning "all
    // platforms".
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

  void setScope(LibraryScope scope) => state = state.copyWith(scope: scope);
  void setType(MediaTypeFilter type) => state = state.copyWith(type: type);
  void setQuery(String query) => state = state.copyWith(query: query);
  void setPlatform(MediaPlatform? platform) =>
      state = state.copyWith(platform: () => platform);

  /// One tag replaces everything, arriving from the "your tags" tab.
  void setTag(String? tag) => state = state.copyWith(
    tags: tag == null ? const {} : {tag},
    excludedTags: const {},
  );

  /// **The three-state tag cycle**: neutral, included, excluded, neutral.
  /// One cycle on the same chip saves a dropdown and a settings screen.
  void cycleTag(String tag) {
    final included = Set<String>.from(state.tags);
    final excluded = Set<String>.from(state.excludedTags);
    if (included.remove(tag)) {
      excluded.add(tag);
    } else if (!excluded.remove(tag)) {
      included.add(tag);
    }
    state = state.copyWith(tags: included, excludedTags: excluded);
  }

  void clearTags() =>
      state = state.copyWith(tags: const {}, excludedTags: const {});

  Future<void> setSort(LibrarySort sort) async {
    state = state.copyWith(sort: sort);
    final mutex = ref.read(prefsMutexProvider);
    await mutex.run(
      () => ref
          .read(keyValueStoreProvider)
          .setString('video_sort_option', sort.name),
    );
  }

  Future<void> setMode(LibraryViewMode mode) async {
    state = state.copyWith(mode: mode);
    final mutex = ref.read(prefsMutexProvider);
    await mutex.run(
      () => ref
          .read(keyValueStoreProvider)
          .setString('library_view_mode', mode.name),
    );
  }

  void toggleSelected(String canonicalUrl) {
    final selection = Set<String>.from(state.selection);
    selection.contains(canonicalUrl)
        ? selection.remove(canonicalUrl)
        : selection.add(canonicalUrl);
    state = state.copyWith(selection: selection);
  }

  void selectAll(Iterable<String> urls) =>
      state = state.copyWith(selection: {...urls});

  void clearSelection() => state = state.copyWith(selection: const {});
}

final libraryViewProvider =
    NotifierProvider<LibraryViewNotifier, LibraryViewOptions>(
      LibraryViewNotifier.new,
    );

/// The list on screen after filtering and sorting.
///
/// **`whenData` was erasing the retained data** (field report 2026-09-03:
/// "the library still flickers while loading"). That function dispatches on
/// the **type** of the state rather than on whether a value exists, so on
/// `AsyncLoading` it returns a **new empty** instance and whatever Riverpod
/// was holding from before is lost.
///
/// And the effect is not a brief flicker: live polling invalidates the
/// history every two seconds, and fetching `/history` for a server with 261
/// items takes about that long, so the provider stays in a nearly
/// continuous loading state. **Measured with a screen recording on the
/// emulator: the library was replaced by a spinner for 13 unbroken seconds
/// during one download, and returned the moment polling stopped.** The
/// ordering in the screen was correct; the value had simply been destroyed
/// before it arrived.
///
/// The rule is now explicit: **a value exists, show it; else the error;
/// else loading.**
final visibleLibraryProvider = Provider<AsyncValue<List<LibraryItem>>>((ref) {
  final options = ref.watch(libraryViewProvider);
  return asyncViewOf(
    ref.watch(libraryItemsProvider),
    (items) => buildLibraryView(
      items,
      scope: options.scope,
      type: options.type,
      query: options.query,
      tags: options.tags,
      excludedTags: options.excludedTags,
      platform: options.platform,
      sort: options.sort,
    ),
  );
});

/// **The peak moment**: it watches for task completions and highlights the
/// item arriving in the library. It lives for the life of the app,
/// watched from the shell, so it never misses a completion that happened
/// while the user was on another screen.
final platformCountsProvider = Provider<List<MapEntry<MediaPlatform, int>>>((
  ref,
) {
  final items = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
  return platformCounts(items);
});

/// The item currently highlighted, from a notification tap or a finished
/// download. It extinguishes itself.
final highlightedItemProvider = StateProvider<String?>((ref) => null);

/// **The peak moment**: it watches for task completions and highlights the
/// item arriving in the library. It lives for the life of the app, watched
/// from the shell, so it never misses a completion that happened while the
/// user was on another screen.
final completionGlowProvider = Provider<void>((ref) {
  final seen = <String>{};
  ref.listen<AsyncValue<List<DownloadTask>>>(engineTasksProvider, (_, next) {
    for (final task in next.valueOrNull ?? const <DownloadTask>[]) {
      if (task.phase != TaskPhase.completed || !seen.add(task.id)) continue;
      final arrived = task.canonicalUrl;
      if (arrived != null) {
        ref.read(highlightedItemProvider.notifier).state = arrived;
      }
    }
  });
});
