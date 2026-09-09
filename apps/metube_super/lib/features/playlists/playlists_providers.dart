import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../library/library_models.dart';
import '../library/library_providers.dart';
import '../player/playback_providers.dart';

/// The pinned smart playlists, built automatically with no maintenance.
enum SmartListKind { favorites, latest, offline }

class SmartList {
  const SmartList({required this.kind, required this.items});

  final SmartListKind kind;
  final List<LibraryItem> items;

  int get count => items.length;
}

/// The last 30 additions; a fixed count stated in the Wahaj reference.
const int latestSmartListSize = 30;

/// The order: pinned first, then **by last played** rather than by creation
/// date. Pure, testable logic (TRD §3.2).
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

/// The three smart playlists derived from the library items: pure logic.
List<SmartList> buildSmartLists(List<LibraryItem> items) {
  final byNewest = [...items]
    ..sort(
      (a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)),
    );
  return [
    SmartList(
      kind: SmartListKind.favorites,
      items: [
        for (final item in byNewest)
          if (item.favorite) item,
      ],
    ),
    SmartList(
      kind: SmartListKind.latest,
      items: byNewest.take(latestSmartListSize).toList(),
    ),
    SmartList(
      kind: SmartListKind.offline,
      items: [
        for (final item in byNewest)
          if (item.isOffline) item,
      ],
    ),
  ];
}

final playlistsProvider = FutureProvider<List<SavedPlaylist>>((ref) async {
  // A write from outside this screen, such as batch collection, arrives
  // through the counter.
  ref.watch(playlistsRevisionProvider);
  return sortPlaylists(await ref.watch(playlistsStoreProvider).readAll());
});

/// Your tags, with counts.
final tagCountsProvider = FutureProvider<Map<String, int>>(
  (ref) => ref.watch(tagsIndexProvider).allTagsWithCounts(),
);

/// The three smart playlists from the current library.
final smartListsProvider = Provider<List<SmartList>>(
  (ref) => buildSmartLists(
    ref.watch(libraryItemsProvider).valueOrNull ?? const <LibraryItem>[],
  ),
);

/// A saved playlist's items after they are matched to the library,
/// **together with the keys of anything that no longer exists**. An item
/// that is gone is built from the data cached in the entry itself, so it
/// does not vanish silently.
///
/// Field report 2026-09-04: "when I remove a video from the playlist it
/// stays there and will not play, or it plays a different clip". An
/// unmatched entry was shown like any other and entered the play queue, so
/// its source failed and the player jumped to the next one, making the tap
/// look as though it had played something else.
///
/// **Nothing is deleted here:** an absence may be temporary, since an
/// unreachable server makes the library local-only. What is missing is
/// marked, and the screen takes care of keeping it out of playback and
/// offering its removal to the user.
class PlaylistView {
  const PlaylistView({required this.items, required this.missing});

  final List<PlaylistItem> items;

  /// The keys of entries with no counterpart, in [items] order.
  final Set<String> missing;

  bool isMissing(PlaylistItem item) => missing.contains(item.canonicalUrl);

  /// What is genuinely playable; only this enters the queue.
  List<PlaylistItem> get playable => [
    for (final item in items)
      if (!isMissing(item)) item,
  ];
}

final playlistItemsProvider = FutureProvider.family<List<PlaylistItem>, String>(
  (ref, id) async => (await ref.watch(playlistViewProvider(id).future)).items,
);

final playlistViewProvider = FutureProvider.family<PlaylistView, String>((
  ref,
  id,
) async {
  final playlist = await ref.watch(playlistsStoreProvider).byId(id);
  if (playlist == null) {
    return const PlaylistView(items: [], missing: {});
  }
  final library = await ref.watch(libraryItemsProvider.future);
  final byUrl = {for (final item in library) item.canonicalUrl: item};
  final items = <PlaylistItem>[];
  final missing = <String>{};
  for (final entry in playlist.items) {
    if (byUrl[entry.canonicalUrl] case final LibraryItem match) {
      items.add(toPlaylistItem(match));
      continue;
    }
    missing.add(entry.canonicalUrl);
    items.add(
      PlaylistItem(
        canonicalUrl: entry.canonicalUrl,
        title: entry.cachedTitle ?? entry.canonicalUrl,
        artworkUrl: entry.cachedThumb,
        serverFilename: entry.serverFilename,
      ),
    );
  }
  return PlaylistView(items: items, missing: missing);
});

/// A playlist entry from a library item; it caches the title and the cover
/// so the card survives.
PlaylistEntry toPlaylistEntry(LibraryItem item) => PlaylistEntry(
  canonicalUrl: item.canonicalUrl,
  serverFilename: item.serverFilename,
  cachedTitle: item.title,
  cachedThumb: item.thumbnail,
);

/// Playing a playlist (rule 7): the tap is "smart". All audio means
/// background playback; anything with video opens the visual player.
/// [audioOnly] is the headphones button, which forces the background.
final playlistPlayerProvider = Provider((ref) => PlaylistPlayer(ref));

class PlaylistPlayer {
  const PlaylistPlayer(this._ref);

  final Ref _ref;

  /// Returns true when playback is visual, and the caller then navigates to
  /// `/player`.
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
      await _ref
          .read(audioHandlerProvider)
          .playItems(items, startIndex: startIndex, playlistId: playlistId);
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
