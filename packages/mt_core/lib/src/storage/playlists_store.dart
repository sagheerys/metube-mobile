import 'dart:convert';

import '../models/saved_playlist.dart';
import 'key_value_store.dart';

/// مخزن القوائم المحفوظة (م-25) تحت مفتاح `saved_playlists` (§5.1) —
/// كل تعديل داخل [PrefsMutex]، ويقرأ صيغة Lite القديمة (videoPaths) تلقائياً.
class PlaylistsStore {
  PlaylistsStore({required this.store, required this.mutex});

  static const String prefsKey = 'saved_playlists';

  final KeyValueStore store;
  final PrefsMutex mutex;

  /// **قراءة دفاعية عنصراً عنصراً (إصلاح خ-1):** كان الالتقاط مقصوراً
  /// على `FormatException`، بينما `SavedPlaylist.fromJson` يرمي
  /// `TypeError` إن وصل `items` خريطةً بدل قائمة (وارد من استعادة نسخة
  /// legacy — والاستعادة تكتب بلا تحقق). النتيجة كانت **كل** `readAll`
  /// يرمي ⇒ شاشة القوائم وكتاباتها معطلة نهائياً بلا شفاء ذاتي.
  /// الآن: قائمة تالفة واحدة تُسقَط، والباقي ينجو.
  Future<List<SavedPlaylist>> readAll() async {
    final raw = await store.getString(prefsKey);
    if (raw == null || raw.isEmpty) return [];
    final Object? decoded;
    try {
      decoded = json.decode(raw);
    } on FormatException {
      return [];
    }
    if (decoded is! List) return [];
    final out = <SavedPlaylist>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      try {
        out.add(SavedPlaylist.fromJson(Map<String, dynamic>.from(item)));
      } on Object {
        continue; // عنصر مشوّه لا يُسقط المخزن كله
      }
    }
    return out;
  }

  Future<SavedPlaylist?> byId(String id) async {
    for (final playlist in await readAll()) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  Future<SavedPlaylist> create(String name,
      {List<PlaylistEntry> items = const []}) async {
    final playlist = SavedPlaylist(name: name, items: List.of(items));
    await _mutateAll((all) => all.add(playlist));
    return playlist;
  }

  Future<void> delete(String id) =>
      _mutateAll((all) => all.removeWhere((p) => p.id == id));

  Future<void> rename(String id, String newName) =>
      _mutateOne(id, (p) => p.name = newName);

  Future<void> setPinned(String id, bool pinned) =>
      _mutateOne(id, (p) => p.pinned = pinned);

  Future<void> touchLastPlayed(String id, {DateTime? at}) =>
      _mutateOne(id, (p) => p.lastPlayedAt = at ?? DateTime.now());

  /// إضافة عناصر (فردي أو جماعي) مع منع التكرار بالرابط المُقنون.
  Future<void> addItems(String id, List<PlaylistEntry> entries) =>
      _mutateOne(id, (p) {
        final existing = p.items.map((e) => e.canonicalUrl).toSet();
        for (final entry in entries) {
          if (entry.canonicalUrl.isEmpty ||
              !existing.contains(entry.canonicalUrl)) {
            p.items.add(entry);
            existing.add(entry.canonicalUrl);
          }
        }
      });

  Future<void> removeItem(String id, String canonicalUrl) =>
      _mutateOne(id, (p) =>
          p.items.removeWhere((e) => e.canonicalUrl == canonicalUrl));

  /// إعادة ترتيب بالسحب.
  Future<void> reorderItem(String id, int oldIndex, int newIndex) =>
      _mutateOne(id, (p) {
        if (oldIndex < 0 || oldIndex >= p.items.length) return;
        final item = p.items.removeAt(oldIndex);
        p.items.insert(newIndex.clamp(0, p.items.length), item);
      });

  Future<void> _mutateOne(String id, void Function(SavedPlaylist) apply) =>
      _mutateAll((all) {
        for (final playlist in all) {
          if (playlist.id == id) {
            apply(playlist);
            return;
          }
        }
      });

  Future<void> _mutateAll(void Function(List<SavedPlaylist>) apply) =>
      mutex.run(() async {
        final all = await readAll();
        apply(all);
        await store.setString(
          prefsKey,
          json.encode(all.map((p) => p.toJson()).toList()),
        );
      });
}
