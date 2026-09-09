import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_equalizer.dart';
import 'mt_highlight_surface.dart';
import 'mt_platform_chip.dart';
import 'mt_location_badge.dart';
import 'mt_polish.dart';

/// Where the item lives, which colours its badge: olive for "offline",
/// soft ember for "on the server".
enum MTMediaLocation { none, offline, onServer, both }

/// The Wahaj media card: a row separated by a hairline rather than a box,
/// full or compact. Presentation only: every value arrives as a ready
/// string or flag from the app layer.
class MTMediaCard extends StatelessWidget {
  const MTMediaCard({
    super.key,
    required this.title,
    this.thumbnail,
    this.duration,
    this.platform = MTPlatformKind.other,
    this.subtitle,
    this.location = MTMediaLocation.none,
    this.locationLabel,
    this.compact = false,
    this.selected = false,
    this.highlighted = false,
    this.playing = false,
    this.paused = false,
    this.favorite = false,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
    this.onMore,
  });

  final String title;

  /// The app supplies the thumbnail, from cached_network_image or a local
  /// file.
  final Widget? thumbnail;
  final String? duration;
  final MTPlatformKind platform;
  final String? subtitle;
  final MTMediaLocation location;
  final String? locationLabel;
  final bool compact;
  final bool selected;

  /// **One highlight that fades**, meaning "look here", not "this is
  /// selected".
  ///
  /// Callers used to pass `selected: true` to draw attention to an item the
  /// user had reached from a notification tap, or that had just finished
  /// downloading. But `selected` everywhere else means "inside a
  /// multi-select", so the item looked stuck in a selection it could not
  /// leave, which is exactly what was described as "it stays marked
  /// forever". There are now two states, distinct visually and in meaning:
  /// selection holds, a highlight passes.
  final bool highlighted;
  final bool playing;

  /// [playing] means "this is the current item"; [paused] means it is
  /// suspended, so the indicator shows still instead of dancing over a clip
  /// that is not running.
  final bool paused;
  final bool favorite;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMore;

  /// The screen-reader description: the title, then whatever distinguishes
  /// this card's state. Built as a single string because a reader announces
  /// the card as one unit.
  String _semanticsLabel(MTLocalizations l10n) => [
    title,
    ?subtitle,
    ?locationLabel,
    if (favorite) l10n.favorites,
    if (playing) l10n.nowPlaying,
  ].join(l10n.listSeparator);

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    final p = x.palette;
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final thumbW = compact ? 64.0 : 98.0;
    final thumbH = compact ? 40.0 : 62.0;

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: _semanticsLabel(l10n),
      // Inner buttons keep their own semantics; their labels are replaced
      // by the combined description.
      explicitChildNodes: true,
      child: MTHighlightSurface(
        selected: selected,
        highlighted: highlighted,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress == null
              ? null
              : () {
                  // Rule 6: entering selection mode deserves a confirming
                  // pulse.
                  HapticFeedback.selectionClick();
                  onLongPress!();
                },
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: compact ? MTSpace.xs : MTSpace.md - 1,
              horizontal: 2,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.line)),
            ),
            child: Row(
              children: [
                _Thumb(
                  width: thumbW,
                  height: thumbH,
                  duration: duration,
                  playing: playing,
                  child: thumbnail,
                ),
                const SizedBox(width: MTSpace.md - 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.55,
                        ),
                      ),
                      SizedBox(height: compact ? 3 : 6),
                      Row(
                        children: [
                          // An unknown platform deserves neither an icon
                          // nor a separator: a bullet followed by "3
                          // minutes ago" is visual noise (audit 8.1).
                          if (platform != MTPlatformKind.other)
                            MTPlatformChip(kind: platform),
                          if (subtitle != null) ...[
                            if (platform != MTPlatformKind.other)
                              Text(
                                ' · ',
                                style: text.bodySmall!.copyWith(color: p.ink3),
                              ),
                            Flexible(
                              child: Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall!.copyWith(color: p.ink3),
                              ),
                            ),
                          ],
                          if (location != MTMediaLocation.none &&
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
                if (playing)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: MTSpace.xs),
                    child: MTEqualizer(animate: !paused),
                  ),
                if (onFavoriteToggle != null)
                  IconButton(
                    tooltip: favorite
                        ? l10n.removeFromFavorites
                        : l10n.addToFavorites,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onFavoriteToggle!();
                    },
                    visualDensity: VisualDensity.compact,
                    // The favourite heart fades and expands rather than
                    // jumping (polish 2026-09-04).
                    icon: MTIconSwap(
                      icon: favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: favorite ? p.favorite : p.ink3,
                    ),
                  ),
                if (onMore != null)
                  IconButton(
                    tooltip: l10n.itemOptions,
                    onPressed: onMore,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: p.ink3,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.width,
    required this.height,
    this.duration,
    this.playing = false,
    this.child,
  });

  final double width;
  final double height;
  final String? duration;
  final bool playing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(MTRadius.thumb),
        border: Border.all(color: p.line),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child ?? Icon(Icons.music_note_rounded, size: 20, color: p.ink3),
          if (duration != null)
            PositionedDirectional(
              bottom: 5,
              start: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        ],
      ),
    );
  }
}
