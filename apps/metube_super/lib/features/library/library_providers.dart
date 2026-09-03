import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show MediaShape;

import '../../di.dart';
import '../shared/async_view.dart';
import 'library_models.dart';

/// عناصر المكتبة الموحدة: done السيرفر + الفهرس المحلي، مفتاح الدمج
/// canonicalUrl بالمطابقة الضبابية (م-13).
final libraryItemsProvider = FutureProvider<List<LibraryItem>>((ref) async {
  final history = await ref.watch(historyProvider.future);
  final offline = await ref.watch(offlineIndexProvider).readAll();
  final tags = await ref.watch(tagsIndexProvider).readAll();
  final artwork = await ref.watch(artworkIndexProvider).readAll();
  final Map<String, MediaShape> shapes =
      await ref.watch(mediaShapeIndexProvider).readAll();

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
    final shape = shapes[entry.canonicalUrl];
    items.add(LibraryItem.fromHistory(
      entry,
      localPath: localPath,
      favorite: isFavorite(entry.canonicalUrl),
      tags: userTags(entry.canonicalUrl),
      duration: shape?.duration,
      aspectRatio: shape?.aspectRatio,
      cachedThumb: artwork[entry.canonicalUrl],
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
      duration: shapes[key]?.duration,
      aspectRatio: shapes[key]?.aspectRatio,
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
    this.tags = const {},
    this.excludedTags = const {},
    this.sort = LibrarySort.newest,
    this.compact = false,
    this.grid = false,
    this.selection = const {},
  });

  final LibraryScope scope;
  final MediaTypeFilter type;
  final String query;

  /// وسوم التضمين (أو بينها) والاستثناء — تصفية مركبة بلا شاشة جديدة.
  final Set<String> tags;
  final Set<String> excludedTags;
  final LibrarySort sort;
  final bool compact;

  /// عرض شبكي بعمودين — أنسب للمسح البصري السريع للفيديو.
  final bool grid;

  /// canonicalUrl المحددة — غير فارغة = وضع التحديد (ر-6).
  final Set<String> selection;

  bool get selecting => selection.isNotEmpty;

  /// عدد المرشحات النشطة فوق «الكل» — لشارة زر الفرز.
  int get activeFilters =>
      (scope == LibraryScope.all ? 0 : 1) +
      (type == MediaTypeFilter.all ? 0 : 1) +
      tags.length +
      excludedTags.length;

  LibraryViewOptions copyWith({
    LibraryScope? scope,
    MediaTypeFilter? type,
    String? query,
    Set<String>? tags,
    Set<String>? excludedTags,
    LibrarySort? sort,
    bool? compact,
    bool? grid,
    Set<String>? selection,
  }) =>
      LibraryViewOptions(
        scope: scope ?? this.scope,
        type: type ?? this.type,
        query: query ?? this.query,
        tags: tags ?? this.tags,
        excludedTags: excludedTags ?? this.excludedTags,
        sort: sort ?? this.sort,
        compact: compact ?? this.compact,
        grid: grid ?? this.grid,
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
    final grid = await store.getBool('library_grid_view') ?? false;
    state = state.copyWith(
      sort: LibrarySort.values
          .where((s) => s.name == sortName)
          .firstOrNull ??
          LibrarySort.newest,
      compact: compact,
      grid: grid,
    );
  }

  void setScope(LibraryScope scope) => state = state.copyWith(scope: scope);
  void setType(MediaTypeFilter type) => state = state.copyWith(type: type);
  void setQuery(String query) => state = state.copyWith(query: query);

  /// وسم واحد يحل محل كل شيء — قدوم من تبويب «وسومك» (م-37/ج).
  void setTag(String? tag) => state = state.copyWith(
        tags: tag == null ? const {} : {tag},
        excludedTags: const {},
      );

  /// **دورة الوسم الثلاثية**: محايد ← مُضمَّن ← مُستثنى ← محايد.
  /// دورة واحدة على نفس الرقاقة تغني عن قائمة منسدلة وشاشة إعدادات.
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

  Future<void> setGrid(bool grid) async {
    state = state.copyWith(grid: grid);
    final mutex = ref.read(prefsMutexProvider);
    await mutex.run(
        () => ref.read(keyValueStoreProvider).setBool('library_grid_view', grid));
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
///
/// **`whenData` كان يمحو البيانات المحفوظة** (بلاغ المالك 2026-09-03:
/// «لا يزال هناك وميض في المكتبة أثناء التحميل»). الدالة توزّع على
/// **نوع** الحالة لا على وجود قيمة، فتعيد عند `AsyncLoading` نسخة
/// **جديدة فارغة** — فيضيع ما يحتفظ به Riverpod من بيانات سابقة.
///
/// والأثر ليس وميضاً خاطفاً: الاستطلاع الحي يُبطل السجل كل ثانيتين
/// وجلب `/history` لسيرفر فيه 261 عنصراً يستغرق قريباً من ذلك، فيبقى
/// المزوّد في حالة تحميل شبه متصلة. **قياس بتسجيل شاشة على المحاكي:
/// المكتبة استُبدلت بدوّارة ١٣ ثانية متصلة أثناء تحميل واحد، ثم عادت
/// لحظة توقف الاستطلاع.** الترتيب في الشاشة كان سليماً — لكن القيمة
/// كانت قد أُتلفت قبل أن تصله.
///
/// القاعدة الآن صريحة: **قيمة موجودة ⇒ تُعرض · وإلا الخطأ · وإلا
/// التحميل**.
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
      sort: options.sort,
    ),
  );
});

/// العنصر الذي يتوهّج الآن: نقرة إشعار أو اكتمال تحميل — يُطفأ من نفسه.
final highlightedItemProvider = StateProvider<String?>((ref) => null);

/// **لحظة الذروة**: يراقب اكتمال المهام فيوهّج العنصر الواصل للمكتبة.
/// يعيش بعمر التطبيق (يُراقَب من الغلاف) كي لا يفوته اكتمال وقع بينما
/// المستخدم في شاشة أخرى.
final completionGlowProvider = Provider<void>((ref) {
  final seen = <String>{};
  ref.listen<AsyncValue<List<DownloadTask>>>(engineTasksProvider, (_, next) {
    for (final task in next.value ?? const <DownloadTask>[]) {
      if (task.phase != TaskPhase.completed || !seen.add(task.id)) continue;
      final arrived = task.canonicalUrl;
      if (arrived != null) {
        ref.read(highlightedItemProvider.notifier).state = arrived;
      }
    }
  });
});
