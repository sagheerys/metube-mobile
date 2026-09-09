import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../downloads_library/library_providers.dart';
import '../downloads_library/local_item.dart';
import '../player/playback_providers.dart';

/// The pinned smart playlists. Lite has no "offline" one, since everything
/// is local.
enum SmartListKind { favorites, latest }

class SmartList {
  const SmartList({required this.kind, required this.items});

  final SmartListKind kind;
  final List<LocalItem> items;

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

/// The two smart playlists derived from the library items: pure logic.
List<SmartList> buildSmartLists(List<LocalItem> items) {
  final byNewest = [...items]..sort((a, b) => b.modified.compareTo(a.modified));
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
  ];
}

final playlistsProvider = FutureProvider<List<SavedPlaylist>>((ref) async {
  // The three smart playlists from the current library.
  ref.watch(playlistsRevisionProvider);
  return sortPlaylists(await ref.watch(playlistsStoreProvider).readAll());
});

final smartListsProvider = Provider<List<SmartList>>(
  (ref) =>
      buildSmartLists(ref.watch(localMediaProvider).valueOrNull ?? const []),
);

/// A saved playlist's items after they are matched to the library,
/// **together with the keys of anything that no longer exists**.
///
/// **Migration from the old Lite:** its entries are file paths
/// ([PlaylistEntry.isLegacy]), so they are matched by path directly and
/// then by bare filename. That is how an imported playlist of 18 entries
/// comes back to life. What does not match is built from its cached data so
/// it does not vanish silently.
///
/// Field report 2026-09-04: "when I remove a video from the playlist it
/// stays there and will not play, or it plays a different clip". An
/// unmatched entry was shown like any other and entered the play queue, so
/// its source failed and the player jumped to the next one, making the tap
/// look as though it had played something else.
///
/// **Nothing is deleted here:** an item's absence may be temporary, a
/// folder not yet rescanned, or in Super an unreachable server. What is
/// missing is only marked, and the screen takes care of keeping it out of
/// playback and offering its removal to the user.
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
    items.add(
      PlaylistItem(
        canonicalUrl: key,
        title:
            entry.cachedTitle ??
            LocalItem.titleFromFilename(
              (entry.legacyPath ?? entry.canonicalUrl).split('/').last,
            ),
        artworkUrl: entry.cachedThumb,
      ),
    );
  }
  return PlaylistView(items: items, missing: missing);
});

/// A playlist entry from a library item; it caches the title and cover so
/// the card stays alive.
PlaylistEntry toPlaylistEntry(LocalItem item) => PlaylistEntry(
  canonicalUrl: item.key,
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
