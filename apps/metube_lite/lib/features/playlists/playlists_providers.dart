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
    buildSmartLists(ref.watch(localMediaProvider).valueOrNull ?? const []));

/// عناصر قائمة محفوظة بعد ربطها بالمكتبة.
///
/// **هجرة Lite القديم:** مداخله مسارات ملفات ([PlaylistEntry.isLegacy])،
/// فتُطابَق بالمسار مباشرة ثم بالاسم المجرد — هكذا تحيا قوائم المالك
/// الـ18 مدخلاً بعد الاستيراد. ما لم يُطابق يُبنى من بياناته المخبأة
/// فلا يختفي بصمت.
/// عناصر القائمة بعد ربطها بالمكتبة، **ومعها مفاتيح ما لم يعد له
/// وجود**.
///
/// بلاغ المالك 2026-09-04: «عند إزالة فيديو من القائمة يظل موجوداً
/// وغير قابل للتشغيل، أو يشغّل مقطعاً آخر». المدخل غير المطابَق كان
/// يُعرض كأي عنصر ويدخل طابور التشغيل — فيفشل مصدره ويقفز المشغل
/// للتالي، فيبدو أن النقرة شغّلت مقطعاً غيره.
///
/// **لا يُحذف شيء هنا:** غياب العنصر قد يكون مؤقتاً (مجلد لم يُمسح
/// بعد، أو سيرفر متعذّر في Super). الغائب يُعلَّم فقط، وتتولى الشاشة
/// إخراجه من التشغيل وعرض إزالته للمستخدم.
class PlaylistView {
  const PlaylistView({required this.items, required this.missing});

  final List<PlaylistItem> items;

  /// مفاتيح المداخل التي لا نسخة لها — بترتيب [items].
  final Set<String> missing;

  bool isMissing(PlaylistItem item) => missing.contains(item.canonicalUrl);

  /// ما يصلح للتشغيل فعلاً — هو وحده ما يدخل الطابور.
  List<PlaylistItem> get playable =>
      [for (final item in items) if (!isMissing(item)) item];
}

final playlistItemsProvider =
    FutureProvider.family<List<PlaylistItem>, String>((ref, id) async =>
        (await ref.watch(playlistViewProvider(id).future)).items);

final playlistViewProvider =
    FutureProvider.family<PlaylistView, String>((ref, id) async {
  final playlist = await ref.watch(playlistsStoreProvider).byId(id);
  if (playlist == null) {
    return const PlaylistView(items: [], missing: {});
  }
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

  final items = <PlaylistItem>[];
  final missing = <String>{};
  for (final entry in playlist.items) {
    if (match(entry) case final LocalItem found) {
      items.add(toPlaylistItem(found));
      continue;
    }
    final key = entry.canonicalUrl.isNotEmpty
        ? entry.canonicalUrl
        : (entry.legacyPath ?? '');
    missing.add(key);
    items.add(PlaylistItem(
      canonicalUrl: key,
      title: entry.cachedTitle ??
          LocalItem.titleFromFilename(
              (entry.legacyPath ?? entry.canonicalUrl).split('/').last),
      artworkUrl: entry.cachedThumb,
    ));
  }
  return PlaylistView(items: items, missing: missing);
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
