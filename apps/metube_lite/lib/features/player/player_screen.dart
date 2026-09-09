import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../di.dart';
import '../downloads_library/library_actions.dart';
import '../downloads_library/library_providers.dart';
import '../downloads_library/local_item.dart';
import '../shared/membership.dart';
import 'playback_providers.dart';

/// Lite's video player (rule 4): every source is local, so the actions are
/// continue as audio, share and open the original link. There is no
/// "available offline".
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
      // about a clip they were already listening to.
      shouldOfferContinueAsAudio: _shouldOfferAudio,
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
    platformOfKey(item.canonicalUrl).label,
    ?membership[item.canonicalUrl]?.line(context.mtl),
  ].join(' · ');

  List<MTPlayerAction> _actions(MTVideoSession session) {
    final l10n = context.mtl;
    final item = session.current;
    if (item == null) return const [];
    return [
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
      if (item.canonicalUrl.startsWith('http'))
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

  LocalItem? _libraryItemOf(PlaylistItem item) {
    final items = ref.read(localMediaProvider).valueOrNull ?? const [];
    for (final candidate in items) {
      if (candidate.key == item.canonicalUrl) return candidate;
    }
    return null;
  }

  Future<void> _share(PlaylistItem item) async {
    final match = _libraryItemOf(item);
    if (match == null) return;
    await ref.read(libraryActionsProvider).share([match]);
  }

  /// Continues the same item as background audio from the same second.
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
    // **Handed to the background here** (field report 2026-09-03): what
    // remains does not touch the session at all, and waiting for the source
    // to load, seconds on a large file, froze the screen so it looked as
    // though the button had done nothing.
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
