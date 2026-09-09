import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../playback/audio_handler.dart';
import '../widgets/media_time.dart';
import '../widgets/mt_player_controls_row.dart';
import '../widgets/mt_progress_slider.dart';
import '../widgets/mt_queue_panel.dart';
import '../widgets/mt_tilted_artwork.dart';
import '../widgets/mt_drag_to_dismiss.dart';
import '../widgets/mt_up_next_list.dart';

/// The full audio screen: a tilted cover, a draggable progress bar,
/// previous and next, the modes and shuffle, and a queue button.
class MTAudioScreen extends StatelessWidget {
  const MTAudioScreen({
    super.key,
    required this.handler,
    this.artwork,
    this.onShowPlaylist,
    this.onDetails,
    this.playlistName,
    this.showSourceChip = true,
  });

  final MTAudioHandler handler;
  final MTArtworkBuilder? artwork;
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
      return MTDragToDismiss(
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MTSpace.xl),
              child: Column(
                children: [
                  _Header(handler: handler, onDetails: onDetails),
                  const Spacer(flex: 2),
                  MTTiltedArtwork(
                    item: item,
                    artwork: artwork,
                    size: _artSize(context),
                  ),
                  const Spacer(),
                  _Titles(
                    item: item,
                    media: media,
                    playlistName: playlistName,
                    index: handler.currentIndex,
                    total: handler.items.length,
                    showSourceChip: showSourceChip,
                  ),
                  const SizedBox(height: MTSpace.xl),
                  _Slider(handler: handler, media: media),
                  const SizedBox(height: MTSpace.md),
                  MTPlayerControlsRow(handler: handler),
                  const SizedBox(height: MTSpace.lg),
                  _SubControls(
                    handler: handler,
                    onQueue: () => _openQueue(context),
                  ),
                  const SizedBox(height: MTSpace.lg),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

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

class _Titles extends StatelessWidget {
  const _Titles({
    required this.item,
    required this.media,
    required this.index,
    required this.total,
    this.playlistName,
    this.showSourceChip = true,
  });

  final PlaylistItem item;
  final MediaItem media;
  final int index;
  final int total;
  final String? playlistName;
  final bool showSourceChip;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l10n = context.mtl;
    final parts = [
      if (media.artist != null && media.artist!.isNotEmpty) media.artist!,
      if (playlistName != null) '«$playlistName»',
      if (total > 1) mtLtrRun(l10n.playlistOf(index + 1, total)),
    ];
    return Column(
      children: [
        if (showSourceChip) ...[
          MTSourceChip(local: item.hasLocal),
          const SizedBox(height: MTSpace.sm),
        ],
        Text(
          media.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleLarge!.copyWith(fontSize: 19),
        ),
        if (parts.isNotEmpty) ...[
          const SizedBox(height: MTSpace.xxs),
          Text(
            parts.join(' · '),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall!.copyWith(color: p.ink3),
          ),
        ],
      ],
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({required this.handler, required this.media});

  final MTAudioHandler handler;
  final MediaItem media;

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
    stream: handler.positionStream,
    builder: (context, snapshot) => MTProgressSlider(
      position: snapshot.data ?? Duration.zero,
      duration: media.duration,
      onSeek: handler.seek,
    ),
  );
}

class _SubControls extends StatelessWidget {
  const _SubControls({required this.handler, required this.onQueue});

  final MTAudioHandler handler;
  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snapshot) {
        final speed = snapshot.data?.speed ?? 1.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Pill(
              onTap: () => handler.setSpeed(mtNextSpeed(speed)),
              leading: '${mtFormatSpeed(speed)}×',
              label: l10n.playbackSpeed,
            ),
            const SizedBox(width: MTSpace.md),
            _Pill(
              onTap: onQueue,
              icon: Icons.queue_music_rounded,
              label: l10n.queueLabel,
              trailing: '${handler.items.length}',
            ),
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.onTap,
    required this.label,
    this.leading,
    this.trailing,
    this.icon,
  });

  final VoidCallback onTap;
  final String label;
  final String? leading;
  final String? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final strong = text.labelSmall!.copyWith(
      color: p.accentInk,
      fontWeight: FontWeight.w700,
    );
    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(MTRadius.field - 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MTRadius.field - 1),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MTSpace.lg,
            vertical: MTSpace.xs + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MTRadius.field - 1),
            border: Border.all(color: p.line2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: p.ink2),
                const SizedBox(width: MTSpace.xs),
              ],
              if (leading != null) ...[
                Text(leading!, style: strong),
                const SizedBox(width: MTSpace.xs),
              ],
              Text(label, style: text.labelSmall!.copyWith(color: p.ink2)),
              if (trailing != null) ...[
                const SizedBox(width: MTSpace.xs),
                Text(trailing!, style: strong),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
