import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../downloads_library/artwork_view.dart';
import '../downloads_library/library_providers.dart';
import '../downloads_library/local_item.dart';

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
/// `media_shape_index`, so knowledge of what counts as a short accumulates.
final videoSessionProvider = Provider.autoDispose<MTVideoSession>((ref) {
  final session = MTVideoSession(
    resolver: ref.watch(playbackResolverProvider),
    positions: ref.watch(playbackPositionsProvider),
    prefs: ref.watch(playbackPrefsProvider),
  );
  final shapes = ref.watch(mediaShapeIndexProvider);
  session.onShapeKnown = (key, duration, aspectRatio) async {
    await shapes.remember(key, duration, aspectRatio);
    ref.invalidate(localMediaProvider);
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

/// Converts a local library item into a unified playback item.
///
/// [PlaylistItem.canonicalUrl] here is **the item key**, a URL or a path,
/// because that is the key for resuming, favourites and playlists in Lite.
/// And [serverFilename] is always null: Lite never streams, and the local
/// file is the only source.
PlaylistItem toPlaylistItem(LocalItem item) => PlaylistItem(
  canonicalUrl: item.key,
  title: item.title,
  artworkUrl: item.thumbnail,
  localPath: item.path,
  isAudio: item.isAudio,
  duration: item.duration,
  aspectRatio: item.aspectRatio,
);

/// The thumbnail builder for the players: platform covers saved in the
/// artwork index, with no authentication headers, since none of them come
/// from the family server.
MTArtworkBuilder artworkBuilderFor(WidgetRef ref) =>
    (context, item) => artworkFor(item.artworkUrl);

/// The platform shown for a playback item, whose key may be a path rather
/// than a URL.
MediaPlatform platformOfKey(String key) =>
    key.startsWith('http') ? MediaPlatform.detect(key) : MediaPlatform.other;
