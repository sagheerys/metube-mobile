import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_equalizer.dart';
import 'mt_highlight_surface.dart';
import 'mt_location_badge.dart';
import 'mt_media_card.dart' show MTMediaLocation;
import 'mt_platform_chip.dart';
import 'mt_polish.dart';

/// The library card **led by its cover**: a 16:9 thumbnail first, with two
/// lines of title underneath. It serves two modes:
///
/// - **Grid**, the default: two columns, so a row shows twice what the
/// list shows and scanning video visually is far quicker.
/// - **Cards** ([feed], requested 2026-09-08, the YouTube pattern): one
/// column with a wide cover and larger text, for unhurried browsing.
///
/// **The two modes share the cover on purpose**: duration, favourite and
/// "more" all live over the thumbnail, and two copies of that would
/// diverge at the first edit. The only differences are text sizes and
/// whether the location badge is shown.
///
/// Presentation only, exactly like [MTMediaCard]: it knows nothing of a
/// server or an index.
class MTMediaGridCard extends StatelessWidget {
  const MTMediaGridCard({
    super.key,
    required this.title,
    this.thumbnail,
    this.duration,
    this.platform = MTPlatformKind.other,
    this.subtitle,
    this.location = MTMediaLocation.none,
    this.locationLabel,
    this.selected = false,
    this.highlighted = false,
    this.playing = false,
    this.paused = false,
    this.favorite = false,
    this.feed = false,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
    this.onMore,
  });

  final String title;
  final Widget? thumbnail;
  final String? duration;
  final MTPlatformKind platform;
  final String? subtitle;
  final MTMediaLocation location;
  final String? locationLabel;
  final bool selected;
  final bool highlighted;
  final bool playing;

  /// [playing] means "this is the current item"; [paused] means it is
  /// suspended, so the indicator shows still instead of dancing over a clip
  /// that is not running.
  final bool paused;
  final bool favorite;

  /// Cards mode: a single column, so there is room for larger text and a
  /// location badge.
  final bool feed;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMore;

  String _semanticsLabel(MTLocalizations l10n) => [
    title,
    ?subtitle,
    ?locationLabel,
    if (favorite) l10n.favorites,
    if (playing) l10n.nowPlaying,
  ].join('، ');

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: _semanticsLabel(l10n),
      explicitChildNodes: true,
      child: MTHighlightSurface(
        selected: selected,
        highlighted: highlighted,
        borderRadius: BorderRadius.circular(MTRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MTRadius.card),
          onLongPress: onLongPress == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onLongPress!();
                },
          child: Padding(
            padding: const EdgeInsets.all(MTSpace.xxs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Cover(
                  duration: duration,
                  playing: playing,
                  paused: paused,
                  favorite: favorite,
                  onFavoriteToggle: onFavoriteToggle,
                  onMore: onMore,
                  child: thumbnail,
                ),
                SizedBox(height: feed ? MTSpace.sm : MTSpace.xs),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (feed ? text.bodyMedium! : text.bodySmall!).copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (platform != MTPlatformKind.other) ...[
                      MTPlatformChip(kind: platform),
                      const SizedBox(width: MTSpace.xxs),
                    ],
                    if (subtitle != null)
                      Flexible(
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: (feed ? text.bodySmall! : text.labelSmall!)
                              .copyWith(color: p.ink3),
                        ),
                      ),
                    // The location badge appears in cards mode only: a grid
                    // cell is half a screen wide and already carries the
                    // chip and the meta line.
                    if (feed &&
                        location != MTMediaLocation.none &&
                        locationLabel != null) ...[
                      const SizedBox(width: MTSpace.xs),
                      MTLocationBadge(
                        location: location,
                        label: locationLabel!,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 16:9 thumbnail carrying duration, favourite and more. Every card
/// action lives on the cover because a grid cell has no width for a column
/// of buttons beside it.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.duration,
    required this.playing,
    required this.paused,
    required this.favorite,
    required this.onFavoriteToggle,
    required this.onMore,
    this.child,
  });

  final String? duration;
  final bool playing;
  final bool paused;
  final bool favorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMore;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.cardAlt,
          borderRadius: BorderRadius.circular(MTRadius.thumb),
          border: Border.all(color: p.line),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child ?? Icon(Icons.music_note_rounded, size: 22, color: p.ink3),
            if (playing)
              Align(
                alignment: Alignment.center,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.ink.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(MTSpace.xs),
                    child: MTEqualizer(animate: !paused),
                  ),
                ),
              ),
            if (duration != null)
              PositionedDirectional(
                bottom: 5,
                start: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: p.ink.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    duration!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: p.bg,
                    ).tabular,
                  ),
                ),
              ),
            PositionedDirectional(
              top: 0,
              end: 0,
              child: Row(
                children: [
                  if (onFavoriteToggle != null)
                    _CoverButton(
                      icon: favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      tooltip: favorite
                          ? l10n.removeFromFavorites
                          : l10n.addToFavorites,
                      // **A fixed white, not `p.bg`** (defect م-3): the
                      // chip always sits over a dark cover, so the theme
                      // background colour made it dark on dark at night,
                      // all but invisible.
                      color: favorite ? p.favorite : Colors.white,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onFavoriteToggle!();
                      },
                    ),
                  if (onMore != null)
                    _CoverButton(
                      icon: Icons.more_vert_rounded,
                      tooltip: l10n.itemOptions,
                      color: Colors.white,
                      onTap: onMore!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverButton extends StatelessWidget {
  const _CoverButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(MTSpace.xs),
        // The favourite heart fades and expands rather than jumping (polish
        // 2026-09-04).
        child: MTIconSwap(
          icon: icon,
          size: 17,
          color: color,
          // Icons over a thumbnail of unknown colour: a light shadow keeps
          // them legible over both pale and dark covers.
          shadows: const [Shadow(color: Color(0x99000000), blurRadius: 5)],
        ),
      ),
    ),
  );
}
