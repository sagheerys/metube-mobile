import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import 'library_models.dart';

/// عناصر المكتبة الموحدة: done السيرفر + الفهرس المحلي، مفتاح الدمج
/// canonicalUrl بالمطابقة الضبابية (م-13).
final libraryItemsProvider = FutureProvider<List<LibraryItem>>((ref) async {
  final history = await ref.watch(historyProvider.future);
  final offline = await ref.watch(offlineIndexProvider).readAll();
  final tags = await ref.watch(tagsIndexProvider).readAll();
  final artwork = await ref.watch(artworkIndexProvider).readAll();

  List<String> userTags(String url) => [
        for (final t in tags[url] ?? const <String>[])
          if (t != MTConstants.favoritesSystemTag) t,
      ];
  bool isFavorite(String url) =>
      (tags[url] ?? const []).contains(MTConstants.favoritesSystemTag);

  final items = <LibraryItem>[];
  final matchedLocal = <String>{};

  for (final entry in history?.done ?? const <HistoryItem>[]) {
    if (!entry.isCompleted) continue;
    String? localPath = offline[entry.canonicalUrl];
    if (localPath == null) {
      for (final MapEntry(:key, :value) in offline.entries) {
        if (UrlKit.urlsMatch(key, entry.canonicalUrl)) {
          localPath = value;
          matchedLocal.add(key);
          break;
        }
      }
    } else {
      matchedLocal.add(entry.canonicalUrl);
    }
    items.add(LibraryItem.fromHistory(
      entry,
      localPath: localPath,
      favorite: isFavorite(entry.canonicalUrl),
      tags: userTags(entry.canonicalUrl),
    ));
  }

  // محلي لم يعد على السيرفر (حُذف هناك) — يبقى في المكتبة الموحدة.
  for (final MapEntry(:key, :value) in offline.entries) {
    if (matchedLocal.contains(key)) continue;
    items.add(LibraryItem.fromOfflineOnly(
      key,
      value,
      favorite: isFavorite(key),
      tags: userTags(key),
      cachedThumb: artwork[key],
    ));
  }
  return items;
});

/// خيارات العرض + التحديد المتعدد — الفرز والعرض محفوظان (م-14).
class LibraryViewOptions {
  const LibraryViewOptions({
    this.scope = LibraryScope.all,
    this.type = MediaTypeFilter.all,
    this.query = '',
    this.tag,
    this.sort = LibrarySort.newest,
    this.compact = false,
    this.selection = const {},
  });

  final LibraryScope scope;
  final MediaTypeFilter type;
  final String query;
  final String? tag;
  final LibrarySort sort;
  final bool compact;

  /// canonicalUrl المحددة — غير فارغة = وضع التحديد (ر-6).
  final Set<String> selection;

  bool get selecting => selection.isNotEmpty;

  LibraryViewOptions copyWith({
    LibraryScope? scope,
    MediaTypeFilter? type,
    String? query,
    String? Function()? tag,
    LibrarySort? sort,
    bool? compact,
    Set<String>? selection,
  }) =>
      LibraryViewOptions(
        scope: scope ?? this.scope,
        type: type ?? this.type,
        query: query ?? this.query,
        tag: tag == null ? this.tag : tag(),
        sort: sort ?? this.sort,
        compact: compact ?? this.compact,
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
    final compact = await store.getBool('library_compact_view') ?? false;
    state = state.copyWith(
      sort: LibrarySort.values
          .where((s) => s.name == sortName)
          .firstOrNull ??
          LibrarySort.newest,
      compact: compact,
    );
  }

  void setScope(LibraryScope scope) => state = state.copyWith(scope: scope);
  void setType(MediaTypeFilter type) => state = state.copyWith(type: type);
  void setQuery(String query) => state = state.copyWith(query: query);
  void setTag(String? tag) => state = state.copyWith(tag: () => tag);

  Future<void> setSort(LibrarySort sort) async {
    state = state.copyWith(sort: sort);
    final mutex = ref.read(prefsMutexProvider);
    await mutex.run(() =>
        ref.read(keyValueStoreProvider).setString('video_sort_option', sort.name));
  }

  Future<void> setCompact(bool compact) async {
    state = state.copyWith(compact: compact);
    final mutex = ref.read(prefsMutexProvider);
    await mutex.run(() => ref
        .read(keyValueStoreProvider)
        .setBool('library_compact_view', compact));
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
        LibraryViewNotifier.new);

/// القائمة المعروضة بعد التصفية والفرز.
final visibleLibraryProvider = Provider<AsyncValue<List<LibraryItem>>>((ref) {
  final options = ref.watch(libraryViewProvider);
  return ref.watch(libraryItemsProvider).whenData(
        (items) => buildLibraryView(
          items,
          scope: options.scope,
          type: options.type,
          query: options.query,
          tag: options.tag,
          sort: options.sort,
        ),
      );
});
