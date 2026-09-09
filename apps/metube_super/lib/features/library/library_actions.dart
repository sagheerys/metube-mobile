import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../di.dart';
import '../settings/auto_backup.dart';
import '../home/network_gate.dart';
import 'library_models.dart';
import 'library_providers.dart';

/// Super's "offline" media folder (§5.3).
const superMediaDir = '/storage/emulated/0/Download/MeTube_Super';

/// The `detail` marker that distinguishes a "Wi-Fi only" refusal from a
/// real network outage; `errorText` reads it to show the right message.
const wifiOnlyRejection = 'wifi-only';

/// Progress of an "available offline" pull in flight: canonicalUrl to 0-1.
final offlinePullProgressProvider = StateProvider<Map<String, double>>(
  (ref) => {},
);

final libraryActionsProvider = Provider((ref) => LibraryActions(ref));

/// Library item actions. All networking goes through the core client and
/// nothing else.
class LibraryActions {
  LibraryActions(this._ref);

  final Ref _ref;

  MeTubeApiClient get _api {
    final api = _ref.read(apiClientProvider);
    if (api == null) throw const NetworkException('no server configured');
    return api;
  }

  void _refreshLibrary() {
    _ref.invalidate(historyProvider);
    _ref.invalidate(libraryItemsProvider);
    // **An automatic backup after every data change** (added 2026-09-04):
    // Lite alone used to back up automatically, and Super's data, tags and
    // playlists over hundreds of items, cannot be reloaded from anywhere.
    unawaited(_ref.read(autoBackupProvider).requestBackup());
  }

  /// Favourites are a system tag, so they enter the backup automatically.
  Future<bool> toggleFavorite(String canonicalUrl) async {
    final tags = _ref.read(tagsIndexProvider);
    await tags.toggleTag(canonicalUrl, MTConstants.favoritesSystemTag);
    _ref.invalidate(libraryItemsProvider);
    unawaited(_ref.read(autoBackupProvider).requestBackup());
    return (await tags.tagsOf(canonicalUrl))
        .contains(MTConstants.favoritesSystemTag);
  }

  /// Is pulling a file to the device allowed right now? Asked before
  /// "available offline" and before a share, which pulls a temporary copy.
  bool get canPullNow =>
      !_ref.read(settingsProvider).wifiOnly ||
      _ref.read(networkGateProvider).onWifi;

  /// "Available offline": a pull with progress, leaving the original on the
  /// server.
  Future<String> makeOffline(LibraryItem item) => pullToDevice(
    canonicalUrl: item.canonicalUrl,
    serverFilename: item.serverFilename,
    title: item.title,
    thumbnail: item.thumbnail,
  );

  /// The same action for an item that has **just completed** and has not
  /// appeared in the library yet. Collecting a batch on the device needs it
  /// before the new `/history` arrives (requested 2026-09-03: "the album
  /// does not download to the device, only to the server").
  Future<String> pullToDevice({
    required String canonicalUrl,
    required String? serverFilename,
    required String title,
    String? thumbnail,
  }) async {
    // **Refused outright rather than waiting**: the add pipeline in Lite
    // has a queue where an item can be patient, but this is a direct action
    // from a user's tap, and leaving it silently "thinking" forever is
    // worse than telling them Wi-Fi is the condition.
    if (!canPullNow) throw const NetworkException(wifiOnlyRejection);
    final filename = serverFilename;
    if (filename == null) throw const UnsafeFilenameException();
    final dir = Directory(superMediaDir);
    await dir.create(recursive: true);
    final savePath =
        '$superMediaDir/${buildLocalFilename(title, serverFilename: filename)}';

    _setProgress(canonicalUrl, 0);
    final String finalPath;
    try {
      // The final path comes from `pull`: a collision shifts it (defect
      // خ-3), and indexing the requested path instead would have pointed at
      // a different file.
      finalPath = await Transfer(api: _api).pull(
        serverFilename: filename,
        savePath: savePath,
        onProgress: (p) => _setProgress(canonicalUrl, p),
      );
    } finally {
      _clearProgress(canonicalUrl);
    }
    await _ref.read(offlineIndexProvider).put(canonicalUrl, finalPath);
    if (thumbnail != null) {
      await _ref.read(artworkIndexProvider).put(canonicalUrl, thumbnail);
    }
    _refreshLibrary();
    return finalPath;
  }

  /// Deletes from the server, **using the canonicalUrl from /history and
  /// nothing else** (rule 2).
  Future<void> deleteFromServer(List<String> canonicalUrls) async {
    await _api.delete(canonicalUrls);
    await pruneItemData(canonicalUrls);
    _refreshLibrary();
  }

  /// **Pruning a removed item's data (fix خ-4).** Deletion used to prune
  /// the offline index alone, while tags, positions, dimensions, the title
  /// and the artwork stayed **forever** in the same XML file that is
  /// re-serialised on every write, and `exportToString` copies whole, so
  /// backups swelled with corpses.
  Future<void> pruneItemData(List<String> canonicalUrls) async {
    final tags = _ref.read(tagsIndexProvider);
    final artwork = _ref.read(artworkIndexProvider);
    final shapes = _ref.read(mediaShapeIndexProvider);
    final positions = _ref.read(playbackPositionsProvider);
    final offline = _ref.read(offlineIndexProvider);
    // Artwork first: it deletes **the thumbnail file itself** along with
    // the entry, or it stays orphaned in `filesDir/thumbs`, which Android
    // never sweeps.
    await artwork.removeKeysAndFiles(canonicalUrls);
    for (final url in canonicalUrls) {
      await tags.removeKey(url);
      await shapes.removeKey(url);
      await positions.clear(url);
      await offline.removeKey(url);
    }
    // **And the saved playlists** (field report 2026-09-04): every index
    // was
    // pruned except the playlists, so a dead entry stayed and played
    // something else when tapped.
    await _ref.read(playlistsStoreProvider).removeFromAll(canonicalUrls);
    _ref.read(playlistsRevisionProvider.notifier).state++;
  }

  /// Deletes a local-only item for good.
  Future<void> removeLocalCopy(LibraryItem item) async {
    final path = item.localPath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _ref.read(offlineIndexProvider).removeKey(item.canonicalUrl);
    _refreshLibrary();
  }

  /// Deletes a local-only item for good.
  Future<void> deleteLocalOnly(LibraryItem item) => removeLocalCopy(item);

  /// Smart sharing: the local file if there is one, otherwise download then
  /// share. **Field report 2026-09-02:** "there is no counter showing it is
  /// downloading, it looks unresponsive". The progress was being computed
  /// in [offlinePullProgressProvider] and nobody displayed it. The share
  /// screens show it now, and the temporary file **is deleted after
  /// sharing** rather than left to accumulate in the system temp folder.
  Future<void> smartShare(LibraryItem item) async {
    final localPath = item.localPath;
    if (localPath != null) {
      await Share.shareXFiles([XFile(localPath)]);
      return;
    }
    if (!canPullNow) throw const NetworkException(wifiOnlyRejection);
    final filename = item.serverFilename;
    if (filename == null) throw const UnsafeFilenameException();
    final tmp = await getTemporaryDirectory();
    final path =
        '${tmp.path}/${buildLocalFilename(item.title, serverFilename: filename)}';
    _setProgress(item.canonicalUrl, 0);
    try {
      await Transfer(api: _api).pull(
        serverFilename: filename,
        savePath: path,
        onProgress: (p) => _setProgress(item.canonicalUrl, p),
      );
    } finally {
      _clearProgress(item.canonicalUrl);
    }
    try {
      await Share.shareXFiles([XFile(path)]);
    } finally {
      // A transient copy the offline index knows nothing about; leaving it
      // is a silent leak.
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // The sharing app is still reading it; the system will clean it up
        // later.
      }
    }
  }

  void _setProgress(String url, double value) {
    final map = Map<String, double>.from(
      _ref.read(offlinePullProgressProvider),
    );
    map[url] = value;
    _ref.read(offlinePullProgressProvider.notifier).state = map;
  }

  void _clearProgress(String url) {
    final map = Map<String, double>.from(
      _ref.read(offlinePullProgressProvider),
    );
    map.remove(url);
    _ref.read(offlinePullProgressProvider.notifier).state = map;
  }
}
