import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../playback/audio_handler.dart';
import 'media_time.dart';
import 'mt_extra_button.dart';
import 'mt_progress_slider.dart';
import 'mt_tilted_artwork.dart';

/// The source chip, the title and the artist line under the cover.
class MTAudioTitles extends StatelessWidget {
  const MTAudioTitles({
    super.key,
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
        MTForeignText(
          media.title,
          center: true,
          maxLines: 2,
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

/// The progress bar, fed by the player's position.
class MTAudioSlider extends StatelessWidget {
  const MTAudioSlider({super.key, required this.handler, required this.media});

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

/// The pills under the controls: speed, the queue, and an app's extra.
class MTAudioSubControls extends StatelessWidget {
  const MTAudioSubControls({
    super.key,
    required this.handler,
    this.onQueue,
    this.extra,
  });

  final MTAudioHandler handler;

  /// Null where the queue is already on screen, as a tab beside the player.
  final VoidCallback? onQueue;
  final MTExtraAction? extra;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snapshot) {
        final speed = snapshot.data?.speed ?? 1.0;
        // One line that shrinks when it must, never two: a second line of
        // pills pushed the whole screen past the bottom of a 360-point
        // phone at a larger text size. Where the pills fit, nothing
        // changes.
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Pill(
                onTap: () => handler.setSpeed(mtNextSpeed(speed)),
                leading: '${mtFormatSpeed(speed)}×',
                label: l10n.playbackSpeed,
              ),
              if (onQueue case final open?) ...[
                const SizedBox(width: MTSpace.md),
                _Pill(
                  onTap: open,
                  icon: Icons.queue_music_rounded,
                  label: l10n.queueLabel,
                  trailing: '${handler.items.length}',
                ),
              ],
              if (extra case final extra?) ...[
                const SizedBox(width: MTSpace.md),
                MTExtraButton(extra: extra),
              ],
            ],
          ),
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
