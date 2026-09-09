import 'dart:convert';

import '../models/saved_playlist.dart';
import 'key_value_store.dart';

/// The saved playlists store, under the `saved_playlists` key (§5.1).
/// Every edit runs inside [PrefsMutex], and the old Lite format
/// (videoPaths) is read automatically.
class PlaylistsStore {
  PlaylistsStore({required this.store, required this.mutex, this.onChanged});

  static const String prefsKey = 'saved_playlists';

  final KeyValueStore store;
  final PrefsMutex mutex;

  /// **Called after every successful write**, the store's single choke
  /// point. The app uses it to request an automatic backup rather than
  /// scattering that call through every screen.
  final void Function()? onChanged;

  /// **Defensive reading, item by item:** the catch used to cover
  /// `FormatException` alone, while `SavedPlaylist.fromJson` throws a
  /// `TypeError` if `items` arrives as a map instead of a list, which
  /// happens when restoring a legacy backup, and restore writes without
  /// validating. The result was that **every** `readAll` threw, so the
  /// playlists screen and all its writes were dead with no self-healing.
  /// Now one corrupt playlist is dropped and the rest survive.
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
        continue; // one malformed item does not bring down the whole store
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

  Future<SavedPlaylist> create(
    String name, {
    List<PlaylistEntry> items = const [],
  }) async {
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

  /// Adds items, one or many, preventing duplicates by canonical URL.
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

  Future<void> removeItem(String id, String canonicalUrl) => _mutateOne(
    id,
    (p) => p.items.removeWhere((e) => e.canonicalUrl == canonicalUrl),
  );

  /// **Removes keys from every playlist**, called when a file is deleted
  /// for good.
  ///
  /// Field report 2026-09-04: "I deleted the playlist's files and they
  /// stayed in the playlist and do not play." Deletion pruned every index,
  /// titles, artwork, tags, positions, **except the playlists**, so a dead
  /// entry stayed and played something else when tapped.
  ///
  /// It compares both keys: [PlaylistEntry.canonicalUrl] and the old Lite
  /// path [PlaylistEntry.legacyPath], since the library key may be either.
  /// Returns how many entries were actually removed.
  Future<int> removeFromAll(Iterable<String> keys) async {
    final targets = {...keys.where((k) => k.isNotEmpty)};
    if (targets.isEmpty) return 0;
    var removed = 0;
    await _mutateAll((all) {
      for (final playlist in all) {
        final before = playlist.items.length;
        playlist.items.removeWhere(
          (e) =>
              targets.contains(e.canonicalUrl) ||
              (e.legacyPath != null && targets.contains(e.legacyPath)),
        );
        removed += before - playlist.items.length;
      }
    });
    return removed;
  }

  /// A playlist with exactly this name, ignoring surrounding whitespace.
  /// Used by the batch collector so a playlist is not duplicated when the
  /// same source is downloaded again.
  Future<SavedPlaylist?> byName(String name) async {
    final target = name.trim();
    if (target.isEmpty) return null;
    for (final playlist in await readAll()) {
      if (playlist.name.trim() == target) return playlist;
    }
    return null;
  }

  /// Reordering by drag.
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
        onChanged?.call();
      });
}
