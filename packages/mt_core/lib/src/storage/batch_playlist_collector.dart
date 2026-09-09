import '../models/download_task.dart';
import '../models/saved_playlist.dart';
import 'playlists_store.dart';

/// **Collecting a playlist download into one saved playlist** (asked
/// 2026-09-02: "when I download a course from YouTube, are they grouped
/// together?").
///
/// The answer was **no**: `isBatchMember` did nothing but order the queue,
/// putting single items ahead of batch members, and the items scattered
/// through the library with no link between them. The earlier project
/// behaved the same way.
///
/// Now the batch screen opens a playlist named after the source, and every
/// item that completes is added to it **in source order rather than
/// completion order** (downloads run one at a time, but a failure shifts
/// the order). A playlist that ends up completely empty, when everything
/// failed, is deleted, so no ghost playlist remains.
class BatchPlaylistCollector {
  BatchPlaylistCollector({required this.playlists, this.onChanged});

  final PlaylistsStore playlists;

  /// **Tells the interface the playlists changed** (field report
  /// 2026-09-03). The collected playlist was written to disk correctly and
  /// **never appeared**: the write happens away from the playlists screen,
  /// and the `indexedStack` shell keeps that tab alive with a provider
  /// holding its cached value, so disk is not read again until the app
  /// restarts.
  final void Function()? onChanged;

  /// taskId to (playlist id, the item's position in the source).
  final Map<String, (String playlistId, int order)> _members = {};

  /// How many are still unfinished per playlist, so an empty one can be
  /// cleaned up at the end.
  final Map<String, int> _remaining = {};

  /// What was actually added per playlist, to know which ended up empty.
  final Map<String, int> _added = {};

  /// The first position for this batch's members inside the playlist: 0 for
  /// a new one, and the existing length when reusing one.
  final Map<String, int> _base = {};

  /// Creates the playlist, **or reuses the one with the same name**, and
  /// registers its tasks. [taskIds] are in source order.
  ///
  /// Field report 2026-09-04: "I downloaded the YouTube playlist again and
  /// it appeared as a new playlist, so now I have two." `create` used to
  /// make a playlist every time without asking. Now the same name means the
  /// same playlist, and duplicate entries are prevented by
  /// [PlaylistsStore.addItems] on the canonical URL, so re-downloading the
  /// source revives dead entries instead of cloning the playlist.
  Future<SavedPlaylist> begin(String name, List<String> taskIds) async {
    final existing = await playlists.byName(name);
    final playlist = existing ?? await playlists.create(name);
    // The requested position is offset by whatever the playlist already
    // holds, or the first batch member would jump to the top of a playlist
    // with ten items in it.
    _base[playlist.id] = existing?.items.length ?? 0;
    for (var i = 0; i < taskIds.length; i++) {
      _members[taskIds[i]] = (playlist.id, i);
    }
    _remaining[playlist.id] = taskIds.length;
    _added[playlist.id] = 0;
    onChanged?.call();
    return playlist;
  }

  /// Called when a task completes, from the engine's `onCompleted`.
  Future<void> onFinished(DownloadTask task) async {
    final member = _members.remove(task.id);
    if (member == null) return;
    final (playlistId, order) = member;
    final url = task.canonicalUrl;
    if (url != null && url.isNotEmpty) {
      await playlists.addItems(playlistId, [
        PlaylistEntry(
          canonicalUrl: url,
          serverFilename: task.serverFilename,
          cachedTitle: task.title,
          cachedThumb: task.thumbnail,
        ),
      ]);
      await _placeAt(playlistId, url, order);
      _added[playlistId] = (_added[playlistId] ?? 0) + 1;
    }
    await _closeIfDone(playlistId);
    onChanged?.call();
  }

  /// Called when a batch member fails or is cancelled: nothing is added,
  /// but
  /// the count advances.
  Future<void> onDropped(String taskId) async {
    final member = _members.remove(taskId);
    if (member == null) return;
    await _closeIfDone(member.$1);
    onChanged?.call();
  }

  /// Puts the item back at its source position, since additions arrive in
  /// completion order.
  Future<void> _placeAt(String playlistId, String url, int order) async {
    final playlist = await playlists.byId(playlistId);
    if (playlist == null) return;
    final current = playlist.items.indexWhere((e) => e.canonicalUrl == url);
    if (current < 0) return;
    final target =
        (order + (_base[playlistId] ?? 0)).clamp(0, playlist.items.length - 1);
    if (current != target) {
      await playlists.reorderItem(playlistId, current, target);
    }
  }

  Future<void> _closeIfDone(String playlistId) async {
    final left = (_remaining[playlistId] ?? 1) - 1;
    _remaining[playlistId] = left;
    if (left > 0) return;
    _remaining.remove(playlistId);
    final base = _base.remove(playlistId) ?? 0;
    final added = _added.remove(playlistId) ?? 0;
    // **A playlist that existed before us is never deleted**: deletion
    // cures
    // a playlist we created ourselves whose members all failed, not a
    // user's
    // playlist we added to.
    if (added == 0 && base == 0) await playlists.delete(playlistId);
  }
}
