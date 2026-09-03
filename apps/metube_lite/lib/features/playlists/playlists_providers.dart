import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../downloads_library/library_providers.dart';
import '../downloads_library/local_item.dart';
import '../player/playback_providers.dart';

/// القوائم الذكية المثبتة (م-37/أ) — Lite بلا «دون اتصال» (كل شيء محلي).
enum SmartListKind { favorites, latest }

class SmartList {
  const SmartList({required this.kind, required this.items});

  final SmartListKind kind;
  final List<LocalItem> items;

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

/// القائمتان الذكيتان من عناصر المكتبة — منطق خالص.
List<SmartList> buildSmartLists(List<LocalItem> items) {
  final byNewest = [...items]
    ..sort((a, b) => b.modified.compareTo(a.modified));
  return [
    SmartList(
      kind: SmartListKind.favorites,
      items: [for (final item in byNewest) if (item.favorite) item],
    ),
    SmartList(
      kind: SmartListKind.latest,
      items: byNewest.take(latestSmartListSize).toList(),
    ),
  ];
}

final playlistsProvider = FutureProvider<List<SavedPlaylist>>((ref) async {
  // كتابةٌ من خارج هذه الشاشة (تجميع الدفعة) تصل عبر العدّاد.
  ref.watch(playlistsRevisionProvider);
  return sortPlaylists(await ref.watch(playlistsStoreProvider).readAll());
});

final smartListsProvider = Provider<List<SmartList>>((ref) =>
    buildSmartLists(ref.watch(localMediaProvider).value ?? const []));

/// عناصر قائمة محفوظة بعد ربطها بالمكتبة.
///
/// **هجرة Lite القديم:** مداخله مسارات ملفات ([PlaylistEntry.isLegacy])،
/// فتُطابَق بالمسار مباشرة ثم بالاسم المجرد — هكذا تحيا قوائم المالك
/// الـ18 مدخلاً بعد الاستيراد. ما لم يُطابق يُبنى من بياناته المخبأة
/// فلا يختفي بصمت.
final playlistItemsProvider =
    FutureProvider.family<List<PlaylistItem>, String>((ref, id) async {
  final playlist = await ref.watch(playlistsStoreProvider).byId(id);
  if (playlist == null) return const [];
  final library = await ref.watch(localMediaProvider.future);
  final byKey = {for (final item in library) item.key: item};
  final byPath = {for (final item in library) item.path: item};
  final byFilename = {for (final item in library) item.filename: item};

  LocalItem? match(PlaylistEntry entry) {
    final legacy = entry.legacyPath;
    if (legacy != null && legacy.isNotEmpty) {
      final normalized = legacy.replaceAll(r'\', '/');
      return byPath[normalized] ?? byFilename[normalized.split('/').last];
    }
    return byKey[entry.canonicalUrl] ?? byPath[entry.canonicalUrl];
  }

  return [
    for (final entry in playlist.items)
      if (match(entry) case final LocalItem found)
        toPlaylistItem(found)
      else
        PlaylistItem(
          canonicalUrl: entry.canonicalUrl.isNotEmpty
              ? entry.canonicalUrl
              : (entry.legacyPath ?? ''),
          title: entry.cachedTitle ??
              LocalItem.titleFromFilename(
                  (entry.legacyPath ?? entry.canonicalUrl).split('/').last),
          artworkUrl: entry.cachedThumb,
        ),
  ];
});

/// مدخل قائمة من عنصر مكتبة — يخبئ العنوان والغلاف لبقاء البطاقة حية.
PlaylistEntry toPlaylistEntry(LocalItem item) => PlaylistEntry(
      canonicalUrl: item.key,
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
