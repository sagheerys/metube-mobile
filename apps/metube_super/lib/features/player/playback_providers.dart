import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../library/artwork_view.dart';
import '../library/library_models.dart';
import '../library/library_providers.dart';

/// A pending play request: the list on screen at the moment of the tap, in
/// its order and with its filtering (rule 4).
class PlaybackRequest {
  const PlaybackRequest({
    required this.items,
    required this.startIndex,
    this.playlistId,
    this.playlistName,
  });

  final List<PlaylistItem> items;
  final int startIndex;
  final String? playlistId;
  final String? playlistName;
}

/// Set before navigating to `/player`, then read once by the screen.
final playbackRequestProvider = StateProvider<PlaybackRequest?>((ref) => null);

/// The video session, built when the player opens and disposed when it is
/// left. It records the dimensions of every clip it plays into
/// `media_shape_index`, so knowledge of what counts as a short accumulates
/// with no extra request to the server.
final videoSessionProvider = Provider.autoDispose<MTVideoSession>((ref) {
  final session = MTVideoSession(
    resolver: ref.watch(playbackResolverProvider),
    positions: ref.watch(playbackPositionsProvider),
    prefs: ref.watch(playbackPrefsProvider),
  );
  final shapes = ref.watch(mediaShapeIndexProvider);
  // **The liveness flag before invalidating:** `remember` waits
  // on the disk, and the player may close during that wait so this provider
  // is disposed (autoDispose), giving a `StateError` in the log on every
  // quick close.
  var alive = true;
  ref.onDispose(() => alive = false);
  session.onShapeKnown = (url, duration, aspectRatio) async {
    await shapes.remember(url, duration, aspectRatio);
    if (alive) ref.invalidate(libraryItemsProvider);
  };
  // **One audio output, in both directions.** Opening a video while
  // background audio played used to play both at once (caught on a real
  // device), and the opposite direction stayed open until later: the
  // play button in the media notification, or starting audio from the
  // playlists screen opened over the player, played over the running video.
  final handler = ref.read(audioHandlerProvider);
  session.onTakeAudioFocus = handler.pause;
  // **Only our own registration is cleared** (2026-09-03): reels registers
  // its stopper too, and clearing the registration indiscriminately left
  // the live side unprotected, so two sources played together.
  final pauseVideo = session.pause;
  handler.onTakeVideoFocus = pauseVideo;
  ref.onDispose(() {
    if (handler.onTakeVideoFocus == pauseVideo) {
      handler.onTakeVideoFocus = null;
    }
    unawaited(session.dispose());
  });
  return session;
});

/// Converts a library item into a unified playback item, keyed by
/// canonicalUrl.
PlaylistItem toPlaylistItem(LibraryItem item) => PlaylistItem(
  canonicalUrl: item.canonicalUrl,
  title: item.title,
  uploader: item.uploader,
  artworkUrl: item.thumbnail,
  localPath: item.localPath,
  serverFilename: item.serverFilename,
  isAudio: item.isAudio,
  duration: item.duration,
  aspectRatio: item.aspectRatio,
);

/// The thumbnail builder for the players; remote images carry the
/// authentication headers.
/// **The headers are read on every image build rather than once:**
/// capturing them in the closure kept the old server's credentials
/// after an automatic switch, so covers failed with 401 until the screen
/// was rebuilt.
MTArtworkBuilder artworkBuilderFor(WidgetRef ref) =>
    (context, item) => artworkFor(
      item.artworkUrl,
      headers: ref.read(apiClientProvider)?.streamingHeaders,
    );
