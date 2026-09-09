import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../di.dart';
import '../library/library_actions.dart';
import '../library/library_models.dart';
import '../library/library_providers.dart';
import '../shared/membership.dart';
import 'playback_providers.dart';

/// Super's video player (rule 4): it feeds `MTVideoScreen` with the app's
/// actions, available offline, continue as audio, share, and open the
/// original link.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  PlaybackRequest? _request;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final request = ref.read(playbackRequestProvider);
    if (request == null || !mounted) return;
    setState(() => _request = request);
    await ref
        .read(videoSessionProvider)
        .open(
          request.items,
          startIndex: request.startIndex,
          playlistId: request.playlistId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    // Watched before any early return: `videoSessionProvider` is
    // autoDispose, so reading it without watching disposes it immediately
    // and nothing runs.
    final session = ref.watch(videoSessionProvider);
    final request = _request;
    if (request == null) {
      return Scaffold(
        appBar: AppBar(),
        body: MTEmptyState(
          icon: Icons.play_disabled_rounded,
          title: l10n.videoPlayer,
          message: l10n.noPlayableSource,
        ),
      );
    }
    // **Read in `build` rather than inside `subtitleBuilder`**: the builder
    // runs while a **child** widget is being built, and `ref.watch` there
    // is outside its permitted scope.
    final membership =
        ref.watch(membershipIndexProvider).valueOrNull ?? const {};

    return MTVideoScreen(
      session: session,
      artwork: artworkBuilderFor(ref),
      playlistName: request.playlistName,
      // **Belonging in landscape** (field report 2026-09-04): there is no
      // info sheet there, so the line under the title is its only home.
      membershipLine: membership[session.current?.canonicalUrl]?.line(
        context.mtl,
      ),
      subtitleBuilder: (context, item) => _subtitle(context, item, membership),
      actions: _actions(session),
      onContinueAsAudio: _continueAsAudio,
      // **Never asked twice** (field report 2026-09-02): someone who had
      // already moved the clip to audio and then pressed back was asked
      // "continue as audio?" about a clip they were already listening to.
      shouldOfferContinueAsAudio: _shouldOfferAudio,
      // Saves the current playback session as a permanent playlist.
      onShowPlaylist: request.playlistId == null
          ? null
          : () => context.push('/playlists/${request.playlistId}'),
    );
  }

  String _subtitle(
    BuildContext context,
    PlaylistItem item,
    Map<String, ItemMembership> membership,
  ) => [
    MediaPlatform.detect(item.canonicalUrl).label,
    if (item.uploader != null) item.uploader!,
    ?membership[item.canonicalUrl]?.line(context.mtl),
  ].join(' · ');

  List<MTPlayerAction> _actions(MTVideoSession session) {
    final l10n = context.mtl;
    final item = session.current;
    if (item == null) return const [];
    // **One name for one action** (field report 2026-09-02): the same
    // action was called "download" in reels and "available offline" here.
    // The new name is deliberately short, because the reels action rail
    // truncates long ones.
    final pulling = ref.watch(offlinePullProgressProvider)[item.canonicalUrl];
    // **The state comes from the live library, not from the playback
    // item**: a `PlaylistItem` is a snapshot taken when the player opened,
    // so the icon stayed on "save to device" after the save completed.
    // (Fixed in reels first, and left here; full review 2026-09-02.)
    final live = ref
        .watch(visibleLibraryProvider)
        .valueOrNull
        ?.where((candidate) => candidate.canonicalUrl == item.canonicalUrl);
    final offline = (live?.isNotEmpty ?? false)
        ? live!.first.isOffline
        : item.hasLocal;
    return [
      MTPlayerAction(
        icon: pulling != null
            ? Icons.downloading_rounded
            : (offline ? Icons.offline_pin_rounded : Icons.download_rounded),
        label: pulling != null
            ? '${(pulling * 100).round()}٪'
            : (offline ? l10n.savedOnDevice : l10n.saveToDevice),
        highlighted: offline,
        onTap: (offline || pulling != null) ? () {} : () => _makeOffline(item),
      ),
      MTPlayerAction(
        icon: Icons.headphones_rounded,
        label: l10n.continueAsAudio,
        onTap: () => _continueAsAudio(item, session.position, pop: true),
      ),
      MTPlayerAction(
        icon: Icons.share_rounded,
        label: l10n.share,
        onTap: () => _share(item),
      ),
      MTPlayerAction(
        icon: Icons.open_in_new_rounded,
        label: l10n.openOriginalLink,
        onTap: () => launchUrl(
          Uri.parse(item.canonicalUrl),
          mode: LaunchMode.externalApplication,
        ),
      ),
    ];
  }

  /// The matching library item: the actions need its full data.
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
    await ref.read(libraryActionsProvider).makeOffline(match);
    if (mounted) showMTSnack(context, context.mtl.madeOffline);
  }

  Future<void> _share(PlaylistItem item) async {
    final match = _libraryItemOf(item);
    if (match == null) return;
    await ref.read(libraryActionsProvider).smartShare(match);
  }

  /// The question is worth asking only if there is something to hand over:
  /// a current clip, and the audio player was not already playing it.
  bool _shouldOfferAudio() {
    final current = ref.read(videoSessionProvider).current;
    if (current == null) return false;
    final handler = ref.read(audioHandlerProvider);
    final playingSame =
        handler.currentItem?.canonicalUrl == current.canonicalUrl;
    return !(playingSame && handler.playbackState.value.playing);
  }

  /// Continues the same item as background audio from the same second.
  Future<void> _continueAsAudio(
    PlaylistItem item,
    Duration position, {
    bool pop = false,
  }) async {
    final session = ref.read(videoSessionProvider);
    final handler = ref.read(audioHandlerProvider);
    final positions = ref.read(playbackPositionsProvider);
    // **Everything belonging to the session is read now**: after closing it
    // is disposed (autoDispose), so `duration` becomes nothing and
    // `ref.read` on it is an error (defect ط-5).
    final ordered = session.orderedItems;
    final playlistId = session.playlistId;
    final duration = session.duration;
    final index = ordered.indexWhere(
      (i) => i.canonicalUrl == item.canonicalUrl,
    );
    // **Before** the audio starts: the video used to continue for the whole
    // time the audio source was loading, so the clip was heard twice (a
    // caught defect, and a long one on a slow network).
    await session.pause();
    await positions.save(item.canonicalUrl, position, duration: duration);
    // **Handed to the background here** (field report 2026-09-03): what
    // remains does not touch the session at all, and waiting for the source
    // to load, seconds on a large file, froze the screen so it looked as
    // though the button had done nothing.
    unawaited(
      handler
          .playItems(
            ordered,
            startIndex: index < 0 ? 0 : index,
            playlistId: playlistId,
          )
          .catchError(
            (Object error) => unawaited(
              ref
                  .read(loggerProvider)
                  .error('continue as audio failed: $error', tag: 'playback'),
            ),
          ),
    );
    if (pop && mounted) context.pop();
  }
}
