import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../library/library_models.dart';
import '../library/library_providers.dart';
import '../player/playback_providers.dart';

/// القوائم الذكية المثبتة (م-37/أ) — تُبنى تلقائياً بلا صيانة.
enum SmartListKind { favorites, latest, offline }

class SmartList {
  const SmartList({required this.kind, required this.items});

  final SmartListKind kind;
  final List<LibraryItem> items;

  int get count => items.length;
}

/// آخر 30 إضافة — عدد ثابت معلن في مرجع «وهج».
const int latestSmartListSize = 30;

/// ترتيب م-37/ب: المثبتة أولاً ثم **بآخر تشغيل** (لا بتاريخ الإنشاء) —
/// منطق خالص قابل للاختبار (TRD §3.2).
List<SavedPlaylist> sortPlaylists(List<SavedPlaylist> input) {
  final all = [...input];
  all.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    final left = a.lastPlayedAt ?? a.createdAt;
    final right = b.lastPlayedAt ?? b.createdAt;
    return right.compareTo(left);
  });
  return all;
}

/// القوائم الذكية الثلاث من عناصر المكتبة — منطق خالص.
List<SmartList> buildSmartLists(List<LibraryItem> items) {
  final byNewest = [...items]..sort((a, b) =>
      (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
  return [
    SmartList(
      kind: SmartListKind.favorites,
      items: [for (final item in byNewest) if (item.favorite) item],
    ),
    SmartList(
      kind: SmartListKind.latest,
      items: byNewest.take(latestSmartListSize).toList(),
    ),
    SmartList(
      kind: SmartListKind.offline,
      items: [for (final item in byNewest) if (item.isOffline) item],
    ),
  ];
}

final playlistsProvider = FutureProvider<List<SavedPlaylist>>((ref) async {
  // كتابةٌ من خارج هذه الشاشة (تجميع الدفعة) تصل عبر العدّاد.
  ref.watch(playlistsRevisionProvider);
  return sortPlaylists(await ref.watch(playlistsStoreProvider).readAll());
});

/// وسومك بعدادات (م-37/ج).
final tagCountsProvider = FutureProvider<Map<String, int>>(
    (ref) => ref.watch(tagsIndexProvider).allTagsWithCounts());

/// القوائم الذكية الثلاث من المكتبة الحالية.
final smartListsProvider = Provider<List<SmartList>>((ref) => buildSmartLists(
    ref.watch(libraryItemsProvider).value ?? const <LibraryItem>[]));

/// عناصر قائمة محفوظة بعد ربطها بالمكتبة — العنصر الذي لم يعد موجوداً
/// يُبنى من البيانات المخبأة في المدخل نفسه فلا يختفي بصمت.
final playlistItemsProvider =
    FutureProvider.family<List<PlaylistItem>, String>((ref, id) async {
  final playlist = await ref.watch(playlistsStoreProvider).byId(id);
  if (playlist == null) return const [];
  final library = await ref.watch(libraryItemsProvider.future);
  final byUrl = {for (final item in library) item.canonicalUrl: item};
  return [
    for (final entry in playlist.items)
      if (byUrl[entry.canonicalUrl] case final LibraryItem match)
        toPlaylistItem(match)
      else
        PlaylistItem(
          canonicalUrl: entry.canonicalUrl,
          title: entry.cachedTitle ?? entry.canonicalUrl,
          artworkUrl: entry.cachedThumb,
          serverFilename: entry.serverFilename,
        ),
  ];
});

/// مدخل قائمة من عنصر مكتبة — يخبئ العنوان والغلاف لبقاء البطاقة حية.
PlaylistEntry toPlaylistEntry(LibraryItem item) => PlaylistEntry(
      canonicalUrl: item.canonicalUrl,
      serverFilename: item.serverFilename,
      cachedTitle: item.title,
      cachedThumb: item.thumbnail,
    );

/// تشغيل قائمة (ر-7): النقر «ذكي» — كلها صوت ⇒ خلفية، فيها فيديو ⇒
/// المشغل المرئي. [audioOnly] هو زر السماعات (م-24) يفرض الخلفية.
final playlistPlayerProvider = Provider((ref) => PlaylistPlayer(ref));

class PlaylistPlayer {
  const PlaylistPlayer(this._ref);

  final Ref _ref;

  /// يعيد true إن كان التشغيل مرئياً (على المنادي أن ينتقل لـ `/player`).
  Future<bool> play(
    List<PlaylistItem> items, {
    String? playlistId,
    String? playlistName,
    int startIndex = 0,
    bool audioOnly = false,
    bool shuffle = false,
  }) async {
    if (items.isEmpty) return false;
    if (playlistId != null) {
      await _ref.read(playlistsStoreProvider).touchLastPlayed(playlistId);
      _ref.invalidate(playlistsProvider);
    }
    if (shuffle) {
      await _ref.read(playbackPrefsProvider).setShuffle(true);
    }
    final visual = !audioOnly && items.any((item) => !item.isAudio);
    if (!visual) {
      await _ref.read(audioHandlerProvider).playItems(
            items,
            startIndex: startIndex,
            playlistId: playlistId,
          );
      return false;
    }
    _ref.read(playbackRequestProvider.notifier).state = PlaybackRequest(
      items: items,
      startIndex: startIndex,
      playlistId: playlistId,
      playlistName: playlistName,
    );
    return true;
  }
}
