import 'dart:math' as math;

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
    this.cover,
    this.companion,
    this.showSourceChip = true,
  });

  final MTAudioHandler handler;

  /// Opens the full audio screen, from a tap on the cover.
  final VoidCallback onOpen;

  /// Folds the panel away; the mini player comes back in its place.
  final VoidCallback onCollapse;
  final MTArtworkBuilder? artwork;

  /// The picture for the square cover; [artwork] when null.
  final MTArtworkBuilder? cover;
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
                  Expanded(
                    child: CustomMultiChildLayout(
                      delegate: _PlayerOverTabs(
                        MediaQuery.textScalerOf(context).scale(_tabsAtLeast),
                      ),
                      children: [
                        LayoutId(
                          id: _PlayerOverTabs.player,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  button: true,
                                  label: l10n.nowPlaying,
                                  child: GestureDetector(
                                    onTap: onOpen,
                                    child: MTTiltedArtwork(
                                      item: item,
                                      artwork: cover ?? artwork,
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
                              ],
                            ),
                          ),
                        ),
                        LayoutId(
                          id: _PlayerOverTabs.tabs,
                          child: MTNowPlayingTabs(
                            handler: handler,
                            artwork: artwork,
                            companion: companion,
                          ),
                        ),
                      ],
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

  /// The tab bar and about one row beneath it, at the normal font; it
  /// grows with the text, since the tabs wrap onto two lines at the largest.
  static const _tabsAtLeast = 120.0;
}

/// **The player at its own height, the tabs below in what is left.** When
/// the window is short and the font large (a small tablet on its side,
/// Android's text enlarged), the player would push the tabs off the
/// bottom: it then scrolls instead, and the tabs keep enough room for
/// their bar and a row. Where everything fits, the player is laid out
/// exactly as a plain column would.
class _PlayerOverTabs extends MultiChildLayoutDelegate {
  _PlayerOverTabs(this.tabsAtLeast);

  static const player = 'player';
  static const tabs = 'tabs';

  final double tabsAtLeast;

  @override
  void performLayout(Size size) {
    final above = layoutChild(
      player,
      BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        maxHeight: math.max(0, size.height - tabsAtLeast),
      ),
    );
    positionChild(player, Offset.zero);
    layoutChild(
      tabs,
      BoxConstraints.tightFor(
        width: size.width,
        height: math.max(0, size.height - above.height),
      ),
    );
    positionChild(tabs, Offset(0, above.height));
  }

  @override
  bool shouldRelayout(_PlayerOverTabs oldDelegate) =>
      oldDelegate.tabsAtLeast != tabsAtLeast;
}
