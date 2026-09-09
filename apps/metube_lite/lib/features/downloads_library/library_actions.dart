import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:share_plus/share_plus.dart';

import '../../di.dart';
import '../settings/auto_backup.dart';
import 'download_wiring.dart';
import 'library_providers.dart';
import 'local_item.dart';

final libraryActionsProvider = Provider((ref) => LibraryActions(ref));

/// Actions on a local library item (rule 5, simplified for Lite): there are
/// no server actions, since the file on the phone is everything and the
/// server was cleaned automatically at download time.
class LibraryActions {
  LibraryActions(this._ref);

  final Ref _ref;

  /// Favourites are a system tag under the item key, so they enter the
  /// backup automatically.
  Future<bool> toggleFavorite(String key) async {
    final tags = _ref.read(tagsIndexProvider);
    await tags.toggleTag(key, MTConstants.favoritesSystemTag);
    _ref.invalidate(localMediaProvider);
    await _ref.read(autoBackupProvider).requestBackup();
    return (await tags.tagsOf(key)).contains(MTConstants.favoritesSystemTag);
  }

  /// Deletes the files for good, cleans the indexes, and rescans the
  /// gallery so no trace of the deleted file is left in MediaStore.
  Future<int> deleteFiles(List<LocalItem> items) async {
    var deleted = 0;
    for (final item in items) {
      final file = File(item.path);
      if (await file.exists()) {
        await file.delete();
        deleted++;
      }
      final url = item.canonicalUrl;
      if (url != null) await _ref.read(offlineIndexProvider).removeKey(url);
      await _ref.read(titleIndexProvider).removeKey(item.key);
      // **Pruning the rest (fix خ-4):** tags, positions and dimensions used
      // to stay forever in the same XML file that is re-serialised on every
      // write, and `exportToString` copies whole, so backups swelled with
      // corpses.
      await _ref.read(tagsIndexProvider).removeKey(item.key);
      await _ref.read(mediaShapeIndexProvider).removeKey(item.key);
      await _ref.read(playbackPositionsProvider).clear(item.key);
      await _ref.read(mediaStoreProvider).scanFile(item.path);
    }
    // The artwork step deletes **the thumbnail file itself** along with the
    // entry, in one pass, because the check "is another key using it?"
    // needs the whole picture.
    await _ref.read(artworkIndexProvider).removeKeysAndFiles([
      for (final item in items) item.key,
    ]);
    // **And the saved playlists** (field report 2026-09-04): every index
    // was
    // pruned except the playlists, so a dead entry stayed and played
    // something else when tapped.
    await _ref.read(playlistsStoreProvider).removeFromAll([
      for (final item in items) ...[item.key, item.path, ?item.canonicalUrl],
    ]);
    _ref.read(playlistsRevisionProvider.notifier).state++;
    _ref.invalidate(localMediaProvider);
    await _ref.read(autoBackupProvider).requestBackup();
    return deleted;
  }

  /// Shares the file itself: no download and no server, since everything in
  /// Lite is local.
  Future<void> share(List<LocalItem> items) async {
    final files = [
      for (final item in items)
        if (File(item.path).existsSync()) XFile(item.path),
    ];
    if (files.isEmpty) return;
    await Share.shareXFiles(files);
  }
}
