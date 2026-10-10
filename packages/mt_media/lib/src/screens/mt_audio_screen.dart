import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../playback/audio_handler.dart';
import '../widgets/mt_extra_button.dart';
import '../widgets/mt_breathing_glow.dart';
import '../widgets/mt_player_controls_row.dart';
import '../widgets/mt_queue_panel.dart';
import '../widgets/mt_tilted_artwork.dart';
import '../widgets/mt_drag_to_dismiss.dart';
import '../video/video_side_panel.dart';
import '../widgets/mt_audio_parts.dart';
import '../widgets/mt_now_playing_tabs.dart';
import '../widgets/mt_up_next_list.dart';

/// The full audio screen: a tilted cover, a draggable progress bar,
/// previous and next, the modes and shuffle, and a queue button.
class MTAudioScreen extends StatelessWidget {
  const MTAudioScreen({
    super.key,
    required this.handler,
    this.artwork,
    this.cover,
    this.onShowPlaylist,
    this.onDetails,
    this.playlistName,
    this.showSourceChip = true,
    this.extra,
    this.companion,
  });

  final MTAudioHandler handler;
  final MTArtworkBuilder? artwork;

  /// The picture for the big square cover, which may want a better one
  /// than a list row; [artwork] when null.
  final MTArtworkBuilder? cover;
  final VoidCallback? onShowPlaylist;

  /// **Clip details**, which replaced the queue button in the header (field
  /// report 2026-09-05): the queue already has its visible button at the
  /// bottom of the screen, and a second one at the top repeats it without
  /// adding anything.
  final VoidCallback? onDetails;
  final String? playlistName;

  /// **The source chip, "streaming from the server" or "playing from your
  /// device"**: information that matters in Super where both sources
  /// coexist, and means nothing in Lite, where everything in the library is
  /// already on the device (field report 2026-09-04).
  final bool showSourceChip;

  /// Asked again for each item as the queue moves: an app feature this
  /// package does not know, such as a transcript, that only some items
  /// have. Null, or a null answer, shows nothing.
  final MTExtraAction? Function(PlaylistItem item)? extra;

  /// Read along beside the player on a tablet, as a tab next to the queue
  /// (a transcript, in Super). On a phone it is reached through [extra].
  final MTVideoPanel? Function(PlaylistItem item)? companion;

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
    stream: handler.mediaItem,
    builder: (context, snapshot) {
      final media = snapshot.data;
      final item = handler.currentItem;
      if (media == null || item == null) {
        return const _EmptyPlayer();
      }
      // **Dragging down returns it to the mini player** (requested
      // 2026-09-04): the screen rose out of it like a sheet, so it is
      // natural to drag it back. The scrubber and the buttons are
      // unaffected, since the gesture is vertical.
      //
      // **The whole Scaffold moves, not its content** (reported with a
      // screenshot): moving the content alone left the screen background in
      // place, showing a dark void above it, whereas what is wanted is the
      // cover and the mini player showing behind it like a sheet being
      // dragged away. That is why its route is non-opaque in the router.
      final size = MediaQuery.sizeOf(context);
      final tablet = size.shortestSide >= MTBreakpoint.tabletSide;
      final sideways = size.width > size.height;
      return MTDragToDismiss(
        child: Scaffold(
          body: SafeArea(
            child: !tablet
                ? sideways
                      ? _sideways(context, item, media)
                      : _player(context, item, media)
                // **A tablet keeps the queue and the transcript in view**
                // (2026-10-10): beside the player when held sideways,
                // under it when upright, instead of a sheet over it.
                : sideways
                ? Row(
                    children: [
                      Expanded(child: _player(context, item, media)),
                      VerticalDivider(
                        width: 1,
                        color: MTThemeX.of(context).palette.line,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(MTSpace.xl),
                          child: _tabs(),
                        ),
                      ),
                    ],
                  )
                : _player(context, item, media, below: _tabs()),
          ),
        ),
      );
    },
  );

  Widget _tabs() => MTNowPlayingTabs(
    handler: handler,
    artwork: artwork,
    companion: companion,
  );

  /// The player column. With [below], a tablet held upright, the cover
  /// gives up part of its height to the tabs, and the pills drop the queue
  /// and the extra, which the tabs already show.
  Widget _player(
    BuildContext context,
    PlaylistItem item,
    MediaItem media, {
    Widget? below,
  }) => MTReadableWidth(
    maxWidth: below == null ? MTBreakpoint.player : MTBreakpoint.readable,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: MTSpace.xl),
      child: Column(
        children: [
          _Header(handler: handler, onDetails: onDetails),
          // The cover takes what the rest leaves, up to its usual size: at
          // Android's largest text on a small phone the fixed-size cover
          // pushed the controls past the bottom. The spare room stays two
          // parts above to one below.
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, box) {
                final size = math.min(
                  _artSize(context),
                  box.maxHeight - MTSpace.lg * 2,
                );
                if (size < _smallestArt) return const SizedBox();
                return Align(
                  alignment: const Alignment(0, 1 / 3),
                  child: MTBreathingGlow(
                    playing: handler.playingNotifier,
                    size: size,
                    child: MTTiltedArtwork(
                      item: item,
                      artwork: cover ?? artwork,
                      size: size,
                    ),
                  ),
                );
              },
            ),
          ),
          MTAudioTitles(
            item: item,
            media: media,
            playlistName: playlistName,
            index: handler.currentIndex,
            total: handler.items.length,
            showSourceChip: showSourceChip,
          ),
          const SizedBox(height: MTSpace.xl),
          MTAudioSlider(handler: handler, media: media),
          const SizedBox(height: MTSpace.md),
          MTPlayerControlsRow(handler: handler),
          const SizedBox(height: MTSpace.lg),
          MTAudioSubControls(
            handler: handler,
            onQueue: _onTablet(context) ? null : () => _openQueue(context),
            extra: _onTablet(context) ? null : extra?.call(item),
          ),
          const SizedBox(height: MTSpace.lg),
          if (below != null) Expanded(flex: 4, child: below),
        ],
      ),
    ),
  );

  /// **A phone held sideways** (field report 2026-10-10: no cover at all).
  /// Stacked in a column, the controls left the cover less height than its
  /// smallest size, so it was dropped. Beside the controls it gets the
  /// screen's full height. The controls scroll rather than overflow at the
  /// largest text.
  Widget _sideways(BuildContext context, PlaylistItem item, MediaItem media) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: MTSpace.xl),
        child: Column(
          children: [
            _Header(handler: handler, onDetails: onDetails),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size =
                            math.min(box.maxWidth, box.maxHeight) -
                            MTSpace.lg * 2;
                        if (size < _smallestArt) return const SizedBox();
                        return Center(
                          child: MTBreathingGlow(
                            playing: handler.playingNotifier,
                            size: size,
                            child: MTTiltedArtwork(
                              item: item,
                              artwork: cover ?? artwork,
                              size: size,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: MTSpace.xl),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MTAudioTitles(
                                item: item,
                                media: media,
                                playlistName: playlistName,
                                index: handler.currentIndex,
                                total: handler.items.length,
                                showSourceChip: showSourceChip,
                              ),
                              const SizedBox(height: MTSpace.md),
                              MTAudioSlider(handler: handler, media: media),
                              MTPlayerControlsRow(handler: handler),
                              const SizedBox(height: MTSpace.sm),
                              MTAudioSubControls(
                                handler: handler,
                                onQueue: () => _openQueue(context),
                                extra: extra?.call(item),
                              ),
                              const SizedBox(height: MTSpace.sm),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  static bool _onTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= MTBreakpoint.tabletSide;

  /// Below this a cover says nothing; the controls get the room instead.
  static const _smallestArt = 64.0;

  double _artSize(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return (size.width - MTSpace.xl * 2).clamp(120.0, size.height * 0.38);
  }

  void _openQueue(BuildContext context) {
    final ordered = handler.orderedItems;
    final currentUrl = handler.currentItem?.canonicalUrl;
    showMTQueueSheet(
      context,
      items: ordered,
      currentIndex: ordered.indexWhere((i) => i.canonicalUrl == currentUrl),
      artwork: artwork,
      playlistName: playlistName,
      liveness: handler.playingNotifier,
      paused: () => !handler.playingNotifier.value,
      onShowAll: onShowPlaylist,
      onSelect: (index) =>
          handler.skipToQueueItem(handler.items.indexOf(ordered[index])),
    );
  }
}

class _EmptyPlayer extends StatelessWidget {
  const _EmptyPlayer();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: MTEmptyState(
      icon: Icons.music_note_rounded,
      title: context.mtl.nowPlaying,
      message: context.mtl.nothingHereYet,
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.handler, this.onDetails});

  final MTAudioHandler handler;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: l10n.dismiss,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: p.ink2),
        ),
        Expanded(
          child: Text(
            l10n.nowPlaying,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall!
                .copyWith(color: p.ink3, letterSpacing: 1.6),
          ),
        ),
        if (onDetails case final VoidCallback show)
          IconButton(
            onPressed: show,
            tooltip: l10n.details,
            icon: Icon(Icons.info_outline_rounded, color: p.ink2),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }
}
