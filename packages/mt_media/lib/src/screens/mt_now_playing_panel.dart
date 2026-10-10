import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../playback/audio_handler.dart';
import '../video/video_side_panel.dart';
import '../widgets/mt_audio_parts.dart';
import '../widgets/mt_now_playing_tabs.dart';
import '../widgets/mt_player_controls_row.dart';
import '../widgets/mt_tilted_artwork.dart';
import '../widgets/mt_up_next_list.dart';

/// **The player beside the library** on a tablet held sideways: cover,
/// controls, and the transcript or the queue underneath, so browsing never
/// hides what is playing. It takes the mini player's place while it shows.
///
/// Empty while nothing plays; the shell gives it no room then.
class MTNowPlayingPanel extends StatelessWidget {
  const MTNowPlayingPanel({
    super.key,
    required this.handler,
    required this.onOpen,
    required this.onCollapse,
    this.artwork,
    this.companion,
    this.showSourceChip = true,
  });

  final MTAudioHandler handler;

  /// Opens the full audio screen, from a tap on the cover.
  final VoidCallback onOpen;

  /// Folds the panel away; the mini player comes back in its place.
  final VoidCallback onCollapse;
  final MTArtworkBuilder? artwork;
  final MTVideoPanel? Function(PlaylistItem item)? companion;
  final bool showSourceChip;

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
    stream: handler.mediaItem,
    builder: (context, snapshot) {
      final media = snapshot.data;
      final item = handler.currentItem;
      if (media == null || item == null) return const SizedBox.shrink();
      final p = MTThemeX.of(context).palette;
      final l10n = context.mtl;
      return SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) {
            // A short window (a small tablet on its side) gives the cover
            // less, never the controls.
            final art = (box.maxHeight * 0.24).clamp(_minArt, _maxArt);
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                MTSpace.lg,
                MTSpace.xs,
                MTSpace.lg,
                0,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.nowPlaying,
                          style: Theme.of(context).textTheme.labelSmall!
                              .copyWith(color: p.ink3, letterSpacing: 1.6),
                        ),
                      ),
                      IconButton(
                        onPressed: onCollapse,
                        tooltip: l10n.nowPlayingCollapse,
                        icon: Icon(
                          Icons.close_fullscreen_rounded,
                          size: 20,
                          color: p.ink2,
                        ),
                      ),
                    ],
                  ),
                  Semantics(
                    button: true,
                    label: l10n.nowPlaying,
                    child: GestureDetector(
                      onTap: onOpen,
                      child: MTTiltedArtwork(
                        item: item,
                        artwork: artwork,
                        size: art,
                      ),
                    ),
                  ),
                  const SizedBox(height: MTSpace.md),
                  MTAudioTitles(
                    item: item,
                    media: media,
                    index: handler.currentIndex,
                    total: handler.items.length,
                    showSourceChip: showSourceChip,
                  ),
                  const SizedBox(height: MTSpace.sm),
                  MTAudioSlider(handler: handler, media: media),
                  MTPlayerControlsRow(handler: handler),
                  const SizedBox(height: MTSpace.sm),
                  Expanded(
                    child: MTNowPlayingTabs(
                      handler: handler,
                      artwork: artwork,
                      companion: companion,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );

  static const _minArt = 88.0;
  static const _maxArt = 180.0;
}
