import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import 'media_time.dart';

/// The app builds the thumbnail, from cached_network_image or a local
/// file; mt_media knows neither the image package nor the server.
/// **Returns `null` when there is no cover**, never an empty `SizedBox`:
/// the fallback, an audio or film icon, is drawn on nothing, and returning
/// an empty widget killed that fallback and left a blank square in the
/// audio player and the mini player (device check 2026-09-05).
typedef MTArtworkBuilder = Widget? Function(
  BuildContext context,
  PlaylistItem item,
);

/// The "up next" rows, the same content in all three shapes: a section
/// under portrait video, a side panel in landscape, a bottom sheet in
/// audio.
class MTUpNextList extends StatelessWidget {
  const MTUpNextList({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.artwork,
    this.dark = false,
    this.paused = false,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<PlaylistItem> items;

  /// The index inside [items] of the item currently playing, or -1 for
  /// none.
  final int currentIndex;
  final ValueChanged<int> onTap;
  final MTArtworkBuilder? artwork;
  final bool dark;

  /// The current item is **paused**, so the indicator stands still rather
  /// than dancing (the same cure as the queue screen: field report
  /// 2026-09-04).
  final bool paused;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) => ListView.builder(
    shrinkWrap: shrinkWrap,
    physics: physics,
    padding: EdgeInsets.zero,
    itemCount: items.length,
    itemBuilder: (context, index) => _UpNextRow(
      item: items[index],
      playing: index == currentIndex,
      paused: paused,
      artwork: artwork,
      dark: dark,
      onTap: () => onTap(index),
    ),
  );
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({
    required this.item,
    required this.playing,
    required this.paused,
    required this.dark,
    required this.onTap,
    this.artwork,
  });

  final PlaylistItem item;
  final bool playing;
  final bool paused;
  final bool dark;
  final VoidCallback onTap;
  final MTArtworkBuilder? artwork;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final ink = dark ? p.miniInk : p.ink;
    final muted = dark ? p.miniInkMuted : p.ink3;
    final line = dark ? p.miniInk.withValues(alpha: 0.08) : p.line;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: MTSpace.sm),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: line)),
        ),
        child: Row(
          children: [
            Container(
              width: dark ? 58 : 74,
              height: dark ? 36 : 46,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: dark ? p.miniInk.withValues(alpha: 0.1) : p.cardAlt,
                borderRadius: BorderRadius.circular(MTRadius.thumb - 2),
                border: Border.all(color: line),
              ),
              child:
                  artwork?.call(context, item) ??
                  Icon(
                    item.isAudio
                        ? Icons.music_note_rounded
                        : Icons.movie_rounded,
                    size: 16,
                    color: muted,
                  ),
            ),
            const SizedBox(width: MTSpace.sm),
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(
                  fontSize: dark ? 10.5 : 12,
                  color: playing ? p.accentInk : (dark ? p.miniInkMuted : ink),
                  fontWeight: playing ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: MTSpace.xs),
            if (playing)
              MTEqualizer(size: 11, animate: !paused)
            else if (item.duration != null)
              Text(
                mtFormatDuration(item.duration!),
                style: text.labelSmall!.copyWith(color: muted).tabular,
              ),
          ],
        ),
      ),
    );
  }
}
