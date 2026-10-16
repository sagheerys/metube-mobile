import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../l10n/bidi.dart';
import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_highlight_surface.dart';
import 'mt_location_badge.dart';
import 'mt_media_card.dart' show MTMediaLocation;
import 'mt_media_thumb.dart';
import 'mt_platform_chip.dart';
import 'mt_polish.dart';

part 'mt_media_row_columns.dart';

/// A library item as a table row, for a tablet: the details a phone hides
/// in the item's sheet sit in their own columns. Presentation only, like
/// [MTMediaCard], whose taps and selection it repeats.
class MTMediaRow extends StatelessWidget {
  const MTMediaRow({
    super.key,
    required this.columns,
    required this.title,
    this.thumbnail,
    this.duration,
    this.size,
    this.added,
    this.platform = MTPlatformKind.other,
    this.subtitle,
    this.tags = const [],
    this.location = MTMediaLocation.none,
    this.locationLabel,
    this.selected = false,
    this.highlighted = false,
    this.favorite = false,
    this.audio = false,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
    this.onMore,
  });

  final MTMediaColumns columns;
  final String title;
  final Widget? thumbnail;
  final String? duration;
  final String? size;

  /// When the item arrived, shown in its own column when there is room.
  /// The caller leaves it out of [subtitle] in that case.
  final String? added;
  final MTPlatformKind platform;
  final String? subtitle;

  /// Shown under the title only on the widest table, beside the date.
  final List<String> tags;
  final MTMediaLocation location;
  final String? locationLabel;
  final bool selected;
  final bool highlighted;
  final bool favorite;
  final bool audio;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMore;

  String _semanticsLabel(MTLocalizations l10n) => [
    title,
    ?subtitle,
    ?duration,
    if (columns.size) ?size,
    if (columns.added) ?added,
    ?locationLabel,
    if (audio) l10n.filterAudio,
    if (favorite) l10n.favorites,
  ].join(l10n.listSeparator);

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall!.copyWith(color: p.ink3);
    final figure = text.bodySmall!.copyWith(color: p.ink2);
    final (titleDirection, titleAlign) = mtForeignLine(context, title);
    final showTags = columns.added && tags.isNotEmpty;

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
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: MTSpace.sm,
              horizontal: MTSpace.xs,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.line)),
            ),
            child: Row(
              children: [
                MTMediaThumb(
                  width: MTMediaColumns.thumbWidth,
                  height: MTMediaColumns.thumbHeight,
                  audio: audio,
                  child: thumbnail,
                ),
                const SizedBox(width: MTSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        textDirection: titleDirection,
                        textAlign: titleAlign,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: MTSpace.xxs),
                      Row(
                        children: [
                          if (platform != MTPlatformKind.other) ...[
                            MTPlatformChip(kind: platform),
                            const SizedBox(width: MTSpace.xxs),
                          ],
                          if (subtitle case final subtitle?
                              when subtitle.isNotEmpty)
                            Flexible(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: small,
                              ),
                            ),
                          if (showTags)
                            for (final tag in tags.take(3))
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: MTSpace.xs,
                                ),
                                child: _Tag(tag),
                              ),
                        ],
                      ),
                    ],
                  ),
                ),
                ..._cells(
                  context,
                  columns,
                  length: _figure(duration, figure),
                  size: _figure(size, figure),
                  added: Text(
                    added ?? '',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: figure,
                  ),
                  location: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child:
                        location == MTMediaLocation.none ||
                            locationLabel == null
                        ? const SizedBox.shrink()
                        : MTLocationBadge(
                            location: location,
                            label: locationLabel!,
                          ),
                  ),
                  actions: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.tag);

  final String tag;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MTSpace.xs - 1),
      decoration: BoxDecoration(
        border: Border.all(color: p.line2),
        borderRadius: BorderRadius.circular(MTRadius.thumb),
      ),
      child: Text(
        '#$tag',
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: p.ink2),
      ),
    );
  }
}
