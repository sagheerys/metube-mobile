import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/library_actions.dart';
import '../library/library_models.dart';
import '../library/library_providers.dart';
import '../library/widgets/item_details_sheet.dart';
import '../shared/add_to_sheet.dart';
import '../shared/membership.dart';
import 'playback_providers.dart';

/// Super's reels player: it builds the shorts lane from the request itself
/// and wires the actions (favourite, download, add to a list, share) to the
/// app's logic.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  /// **Captured once while this screen is alive** (a field defect,
  /// 2026-09-03). The child player calls [_setLive] from its own
  /// `dispose()`, and the tree is **deactivated** by then: `ref.read`
  /// throws there, and the throw used to abort the rest of `dispose()`,
  /// leaving a clip playing with no owner.
  late final MTAudioHandler _audio = ref.read(audioHandlerProvider);

  /// The last "stopper" we handed to the background player, to tell our
  /// registration apart from anyone else's.
  Future<void> Function()? _pauser;

  /// **We never clear another owner's registration:** the video screen
  /// registers itself too, and our death after its birth used to erase its
  /// registration, so two sources played together.
  void _setLive(Future<void> Function()? pauser) {
    if (pauser == null) {
      if (_audio.onTakeVideoFocus == _pauser) _audio.onTakeVideoFocus = null;
      _pauser = null;
      return;
    }
    _pauser = pauser;
    _audio.onTakeVideoFocus = pauser;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final request = ref.watch(playbackRequestProvider);
    if (request == null) {
      return Scaffold(
        appBar: AppBar(),
        body: MTEmptyState(
          icon: Icons.bolt_rounded,
          title: l10n.shortsFilter,
          message: l10n.noPlayableSource,
        ),
      );
    }

    // Read here rather than inside the constructors: `ref.watch` is allowed
    // in `build` alone, and it is what rebuilds the actions when the
    // library changes or a pull advances.
    final library = ref.watch(visibleLibraryProvider).valueOrNull ?? const [];
    final byUrl = {for (final item in library) item.canonicalUrl: item};
    final pulls = ref.watch(offlinePullProgressProvider);
    // **Read in `build` rather than inside `subtitleBuilder`**: the builder
    // runs while a **child** widget is being built, and `ref.watch` there
    // is outside its permitted scope.
    final membership =
        ref.watch(membershipIndexProvider).valueOrNull ?? const {};

    final lane = ShortsLane.from(request.items);
    final startUrl = request.items[request.startIndex].canonicalUrl;
    final laneIndex = lane.laneIndexOf(startUrl);
    if (lane.isEmpty || laneIndex < 0) {
      return Scaffold(
        appBar: AppBar(),
        body: MTEmptyState(
          icon: Icons.bolt_rounded,
          title: l10n.shortsFilter,
          message: l10n.noResultsMessage,
        ),
      );
    }

    return MTReelsPlayer(
      lane: lane,
      resolver: ref.watch(playbackResolverProvider),
      startIndex: laneIndex,
      onTakeAudioFocus: _audio.pause,
      // While the reel is alive, starting audio from the
      // notification silences it first.
      onLive: _setLive,
      subtitleBuilder: (context, item) => [
        MediaPlatform.detect(item.canonicalUrl).label,
        if (item.uploader != null) item.uploader!,
        // From the live library: `item.hasLocal` is an old snapshot that
        // never updates.
        if (byUrl[item.canonicalUrl]?.isOffline ?? item.hasLocal)
          l10n.availabilityOffline,
        // **Belonging under the title** (field report 2026-09-04): which
        // tag and which playlist. The information was in the store and
        // appeared in no player.
        ?membership[item.canonicalUrl]?.line(l10n),
      ].join(' · '),
      isFavorite: (item) => byUrl[item.canonicalUrl]?.favorite ?? false,
      // **No heart in the rail** (field report 2026-09-04): the "add to…"
      // button below covers favourites, tags and playlists together. A
      // double tap on the clip stays the favourite shortcut, through
      // [onDoubleTapFavorite].
      onDoubleTapFavorite: (item) =>
          ref.read(libraryActionsProvider).toggleFavorite(item.canonicalUrl),
      // **The state is read from the live library rather than from the
      // playback item** (field report 2026-09-02): a `PlaylistItem` is a
      // snapshot from when the player opened, so the download button stayed
      // as it was after the offline copy completed. And `pulls` supplies
      // the percentage, so the button does not look dead while pulling.
      actionsBuilder: (item) {
        final match = byUrl[item.canonicalUrl];
        final offline = match?.isOffline ?? item.hasLocal;
        final progress = pulls[item.canonicalUrl];
        return [
          MTPlayerAction(
            icon: Icons.info_outline_rounded,
            label: l10n.details,
            onTap: () {
              if (match != null) showItemDetailsSheet(context, match);
            },
          ),
          MTPlayerAction(
            icon: Icons.playlist_add_rounded,
            label: l10n.addTo,
            onTap: () {
              if (match != null) showAddToSheet(context, ref, match);
            },
          ),
          if (progress != null)
            MTPlayerAction(
              icon: Icons.downloading_rounded,
              label: l10n.percentValue((progress * 100).round()),
              onTap: () {},
            )
          else if (!offline)
            // The same label as the landscape player: it was "download"
            // here and "available offline" there for exactly the same
            // action.
            MTPlayerAction(
              icon: Icons.download_rounded,
              label: l10n.saveToDevice,
              onTap: () => _makeOffline(item),
            )
          else
            MTPlayerAction(
              icon: Icons.offline_pin_rounded,
              label: l10n.savedOnDevice,
              highlighted: true,
              onTap: () {},
            ),
          MTPlayerAction(
            icon: Icons.share_rounded,
            label: l10n.share,
            onTap: () => _share(item),
          ),
        ];
      },
      // The button is not shown at all when the displayed list is entirely
      // shorts.
      onContinueRest: lane.nextNonShortIndex(request.items) == null
          ? null
          : () => _continueRest(request, lane),
    );
  }

  LibraryItem? _libraryItemOf(PlaylistItem item) {
    final items = ref.read(visibleLibraryProvider).valueOrNull ?? const [];
    for (final candidate in items) {
      if (candidate.canonicalUrl == item.canonicalUrl) return candidate;
    }
    return null;
  }

  Future<void> _makeOffline(PlaylistItem item) async {
    final match = _libraryItemOf(item);
    if (match == null) return;
    final l10n = context.mtl;
    try {
      await ref.read(libraryActionsProvider).makeOffline(match);
      if (mounted) {
        showMTSnack(
          context,
          l10n.availableOfflineNow,
          type: MTSnackType.success,
        );
      }
    } on Object {
      if (mounted) {
        showMTSnack(context, l10n.failed, type: MTSnackType.error);
      }
    }
  }

  Future<void> _share(PlaylistItem item) async {
    final match = _libraryItemOf(item);
    if (match == null) return;
    await ref.read(libraryActionsProvider).smartShare(match);
  }

  /// "Continue with the rest of the list": the first non-short item opens
  /// in its correct player.
  Future<void> _continueRest(PlaybackRequest request, ShortsLane lane) async {
    final index = lane.nextNonShortIndex(request.items);
    if (index == null) return context.pop();
    final next = request.items[index];
    if (next.isAudio) {
      // We close reels **first** so its controller is disposed: starting
      // the audio before closing leaves the reel running for the whole
      // load, two sounds at once.
      final handler = ref.read(audioHandlerProvider);
      context.pop();
      await handler.playItems(request.items, startIndex: index);
      return;
    }
    ref.read(playbackRequestProvider.notifier).state = PlaybackRequest(
      items: request.items,
      startIndex: index,
      playlistId: request.playlistId,
      playlistName: request.playlistName,
    );
    if (mounted) context.pushReplacement('/player');
  }
}
