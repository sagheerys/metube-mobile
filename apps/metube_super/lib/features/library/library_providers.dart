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

  final done = [
    for (final entry in history?.done ?? const <HistoryItem>[])
      if (entry.isCompleted) entry,
  ];

  // **تمريرتان لا واحدة** (عطل المالك 2026-09-08): المطابقة الحرفية
  // أولاً **لكل** العناصر، ثم الضبابية على ما بقي. بتمريرة واحدة يسرق
  // عنصرٌ سابق بمطابقة ضبابية مفتاحاً يملكه عنصر لاحق حرفياً.
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
      // **الملف الواحد لا يُمنح لعنصرين**: كانت روابط فيسبوك تتطابق
      // كلها (أُصلح في `UrlKit`)، فيظهر ملف العنصر المُتاح دون اتصال
      // تحت كل عناصر فيسبوك ويُفتح في المشغل الخارجي بدلاً عنها.
      // الحدّ هنا يجعل العرَض مستحيلاً ولو تصادمت مطابقةٌ أخرى غداً.
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
    this.platform,
    this.sort = LibrarySort.newest,
    this.mode = LibraryViewMode.list,
    this.selection = const {},
  });

  final LibraryScope scope;
  final MediaTypeFilter type;
  final String query;

  /// وسوم التضمين (أو بينها) والاستثناء — تصفية مركبة بلا شاشة جديدة.
  final Set<String> tags;
  final Set<String> excludedTags;

  /// **مرشح المنصة** (طلب المالك 2026-09-08 — مثل Lite): يعيش في ورقة
  /// الفرز لا في صفٍّ ثالث من الرقائق، فالمكتبة هنا فوقها صف مرشحات
  /// وصف وسوم أصلاً وثالثٌ كان سيدفع أول بطاقة خارج الشاشة. المنصة
  /// المختارة تظهر رقاقةً قابلة للإزالة في **الصف الأول**.
  final MediaPlatform? platform;
  final LibrarySort sort;

  /// وضع العرض المحفوظ — واحد من أربعة، لا أعلام متداخلة.
  final LibraryViewMode mode;

  bool get compact => mode == LibraryViewMode.compact;
  bool get grid => mode == LibraryViewMode.grid;
  bool get cards => mode == LibraryViewMode.cards;

  /// canonicalUrl المحددة — غير فارغة = وضع التحديد (ر-6).
  final Set<String> selection;

  bool get selecting => selection.isNotEmpty;

  /// عدد المرشحات النشطة فوق «الكل» — لشارة زر الفرز.
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
  }) =>
      LibraryViewOptions(
        scope: scope ?? this.scope,
        type: type ?? this.type,
        query: query ?? this.query,
        tags: tags ?? this.tags,
        excludedTags: excludedTags ?? this.excludedTags,
        // دالة لا قيمة: `null` تعني «لا تغيير» في كل حقل آخر، وهنا
        // `null` قيمةٌ صالحة تعني «كل المنصات».
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
      sort: LibrarySort.values
          .where((s) => s.name == sortName)
          .firstOrNull ??
          LibrarySort.newest,
      mode: await _restoreMode(store),
    );
  }

  /// **هجرة صامتة من المفتاحين القديمين**: من يحدّث التطبيق وهو على
  /// «مضغوط» أو «شبكي» يجب أن يجد وضعه كما تركه — لا أن يرتد للقائمة.
  /// المفتاح الجديد يُكتب عند أول تغيير، والقديمان يُقرآن ما لم يوجد.
  Future<LibraryViewMode> _restoreMode(KeyValueStore store) async {
    final name = await store.getString('library_view_mode');
    final saved =
        LibraryViewMode.values.where((m) => m.name == name).firstOrNull;
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

  Future<void> setMode(LibraryViewMode mode) async {
    state = state.copyWith(mode: mode);
    final mutex = ref.read(prefsMutexProvider);
    await mutex.run(() => ref
        .read(keyValueStoreProvider)
        .setString('library_view_mode', mode.name));
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
      platform: options.platform,
      sort: options.sort,
    ),
  );
});

/// عدّادات رقائق المنصات — تُحسب على المكتبة كاملة لا على المعروض،
/// كي لا تختفي المنصة التي تنقر عليها من القائمة بعد النقر.
final platformCountsProvider =
    Provider<List<MapEntry<MediaPlatform, int>>>((ref) {
  final items = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
  return platformCounts(items);
});

/// العنصر الذي يتوهّج الآن: نقرة إشعار أو اكتمال تحميل — يُطفأ من نفسه.
final highlightedItemProvider = StateProvider<String?>((ref) => null);

/// **لحظة الذروة**: يراقب اكتمال المهام فيوهّج العنصر الواصل للمكتبة.
/// يعيش بعمر التطبيق (يُراقَب من الغلاف) كي لا يفوته اكتمال وقع بينما
/// المستخدم في شاشة أخرى.
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
