import 'dart:io';

import 'url_keyed_index.dart';

/// The artwork index: canonicalUrl to the cover URL captured at add time.
/// The only fallback allowed for non-YouTube sources, since ytimg URLs are
/// never invented (trap §6.3). Prefs key: `artwork_index` (§5.1).
final class ArtworkIndex extends UrlKeyedIndex<String> {
  ArtworkIndex({required super.store, required super.mutex})
    : super(prefsKey: 'artwork_index');

  @override
  String? decodeValue(dynamic raw) {
    final s = raw?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  dynamic encodeValue(String value) => value;

  Future<String?> artworkOf(String canonicalUrl) => valueOf(canonicalUrl);

  /// **Removing the entry and its file on disk together** (defect found
  /// 2026-09-08).
  ///
  /// Deletion used to drop the line from the index and leave an orphan JPG
  /// in `filesDir/thumbs`. After thumbnails moved from `cacheDir`, which
  /// Android sweeps, to `filesDir`, which nobody sweeps, that became an
  /// **unbounded space leak**: 30KB per deletion, invisible to the user and
  /// unrecoverable short of clearing all app data.
  ///
  /// Two guards stop us deleting what is not ours:
  /// * a value starting with `http` is a remote URL (YouTube covers), not a
  /// file.
  /// * a path another key still points at is kept, so a surviving item does
  /// not lose its cover because its neighbour was deleted.
  Future<void> removeKeysAndFiles(Iterable<String> canonicalUrls) async {
    final doomed = canonicalUrls.toSet();
    if (doomed.isEmpty) return;
    final all = await readAll();
    final stillUsed = <String>{
      for (final entry in all.entries)
        if (!doomed.contains(entry.key)) entry.value,
    };
    for (final key in doomed) {
      final path = all[key];
      if (path == null || path.startsWith('http')) continue;
      if (stillUsed.contains(path)) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // A locked file, or one we lack permission for. The entry is
        // removed either way.
      }
    }
    await mutate((map) => map.removeWhere((k, _) => doomed.contains(k)));
  }
}
