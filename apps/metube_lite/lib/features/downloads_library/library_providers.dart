import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show MediaShape;

import '../../di.dart';
import '../shared/async_view.dart';
import 'local_item.dart';

/// المكتبة المحلية (م-12): **مسح المجلد** هو المصدر — الملف الموجود
/// فعلاً يُعرض، والفهارس تُثريه فقط. هكذا تظهر ملفات Lite القديم بعد
/// الهجرة، وتختفي الملفات المحذوفة من خارج التطبيق بلا أشباح.
final localMediaProvider = FutureProvider<List<LocalItem>>((ref) async {
  final offline = await ref.watch(offlineIndexProvider).readAll();
  final titles = await ref.watch(titleIndexProvider).readAll();
  final artwork = await ref.watch(artworkIndexProvider).readAll();
  final tags = await ref.watch(tagsIndexProvider).readAll();
  final Map<String, MediaShape> shapes =
      await ref.watch(mediaShapeIndexProvider).readAll();

  // عكس فهرس «دون اتصال» (canonicalUrl → مسار) لنعرف رابط كل ملف.
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
    items.add(LocalItem(
      key: key,
      path: path,
      canonicalUrl: url,
      title: titles[key] ??
          titles[path] ??
          LocalItem.titleFromFilename(path.split('/').last),
      sizeBytes: stat.size,
      modified: stat.modified,
      thumbnail: artwork[key] ?? artwork[path],
      favorite: (tags[key] ?? tags[path] ?? const [])
          .contains(MTConstants.favoritesSystemTag),
      duration: shape?.duration,
      aspectRatio: shape?.aspectRatio,
    ));
  }
  return items;
});

/// خيارات العرض + التحديد المتعدد — الفرز والعرض محفوظان (م-14).
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

  /// مرشح المنصة بعدادات حية (م-14 — خاص بـ Lite).
  final MediaPlatform? platform;
  final LibrarySort sort;

  /// وضع العرض المحفوظ — واحد من أربعة، لا أعلام متداخلة (نُقل الشبكي
  /// من Super بطلب المالك 2026-09-04، والبطاقات 2026-09-08).
  final LibraryViewMode mode;

  bool get compact => mode == LibraryViewMode.compact;
  bool get grid => mode == LibraryViewMode.grid;
  bool get cards => mode == LibraryViewMode.cards;

  /// مفاتيح العناصر المحددة — غير فارغة = وضع التحديد (ر-6).
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
  }) =>
      LibraryViewOptions(
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
      sort: LibrarySort.values.where((s) => s.name == sortName).firstOrNull ??
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

  void setScope(LocalScope scope) => state = state.copyWith(scope: scope);
  void setType(MediaTypeFilter type) => state = state.copyWith(type: type);
  void setQuery(String query) => state = state.copyWith(query: query);
  void setPlatform(MediaPlatform? platform) =>
      state = state.copyWith(platform: () => platform);

  Future<void> setSort(LibrarySort sort) async {
    state = state.copyWith(sort: sort);
    await ref.read(prefsMutexProvider).run(() =>
        ref.read(keyValueStoreProvider).setString('video_sort_option', sort.name));
  }

  Future<void> setMode(LibraryViewMode mode) async {
    state = state.copyWith(mode: mode);
    await ref.read(prefsMutexProvider).run(() => ref
        .read(keyValueStoreProvider)
        .setString('library_view_mode', mode.name));
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
        LibraryViewNotifier.new);

/// القائمة المعروضة بعد التصفية والفرز.
///
/// **`whenData` كان يمحو البيانات المحفوظة** (بلاغ المالك 2026-09-03،
/// مُستنسخ على Super بتسجيل شاشة: المكتبة استُبدلت بدوّارة ١٣ ثانية
/// أثناء تحميل واحد). الدالة توزّع على **نوع** الحالة لا على وجود
/// قيمة، فتعيد عند `AsyncLoading` نسخة **جديدة فارغة** — فيضيع ما
/// يحتفظ به Riverpod من بيانات سابقة، ويظهر الترتيب في الشاشة كأنه
/// بلا أثر. Lite يعيد مسح المجلد بعد كل اكتمال فيصيبه الشيء نفسه.
///
/// القاعدة الآن صريحة: **قيمة موجودة ⇒ تُعرض · وإلا الخطأ · وإلا
/// التحميل**.
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

/// عدّادات رقائق المنصات — تُحسب على المكتبة كاملة لا على المعروض،
/// كي لا تختفي الرقاقة التي تنقر عليها.
final platformCountsProvider =
    Provider<List<MapEntry<MediaPlatform, int>>>((ref) {
  final items = ref.watch(localMediaProvider).valueOrNull ?? const [];
  return platformCounts(items);
});

/// العنصر الذي يجب إبرازه (نقرة إشعار الاكتمال — `03-APP-FLOW.md` §1).
final highlightedItemProvider = StateProvider<String?>((ref) => null);
