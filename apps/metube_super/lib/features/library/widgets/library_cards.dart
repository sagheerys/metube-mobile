import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';
import '../../home/add_flow.dart';
import '../artwork_view.dart';
import '../library_actions.dart';
import '../library_models.dart';
import '../library_providers.dart';
import 'item_actions_sheet.dart';

/// The library item card: **one source for all four view modes**.
///
/// Split out of `library_screen.dart` when the grid view was added (rule
/// 4): two copies of the same logic would have diverged at the first edit,
/// and nobody would remember that the "offline" badge is set in two
/// places.
///
/// The mode is read straight from the options rather than from a
/// parameter: the screen used to pass `grid: true` while the card read
/// `compact` from the provider, two sources for one decision.
class LibraryItemCard extends ConsumerWidget {
  const LibraryItemCard({
    super.key,
    required this.item,
    required this.onPlay,
    this.columns,
  });

  final LibraryItem item;
  final VoidCallback onPlay;

  /// Set for a row in a tablet's table ([MTLibrarySliver]).
  final MTMediaColumns? columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);
    final actions = ref.read(libraryActionsProvider);
    // **Pull progress was being computed and nobody displayed it** (field
    // report 2026-09-02: "no counter appears, it looks unresponsive"),
    // whether from "save to device" or from a share, which pulls a
    // temporary copy first.
    final pulling = ref.watch(offlinePullProgressProvider)[item.canonicalUrl];
    final highlighted = ref.watch(highlightedItemProvider) == item.canonicalUrl;

    final subtitle = pulling != null
        ? '${l10n.pullingToDevice} ${l10n.percentValue((pulling * 100).round())}'
        // **Each part isolated** (field report 2026-09-20): a channel
        // named in one language beside a time phrase in another had no
        // defined place for the separator between them.
        : mtMetaLine([
            item.uploader,
            // A table with a date column shows it there instead.
            if (item.timestamp != null && columns?.added != true)
              mtTimeAgo(context, item.timestamp!),
          ]);
    final locationLabel = switch (item.location) {
      MTMediaLocation.offline ||
      MTMediaLocation.both => l10n.availabilityOffline,
      MTMediaLocation.onServer => l10n.filterServer,
      MTMediaLocation.none => null,
    };
    // **Decode at display size, not at original size**: a 1280x720
    // thumbnail
    // in a 98-point box reserved about 3.5MB per visible card in the image
    // cache.
    final (thumbWidth, thumbHeight) = columns != null
        ? (MTMediaColumns.thumbWidth, MTMediaColumns.thumbHeight)
        : _thumbBox(context, options.mode);
    final thumbnail = artworkFor(
      item.thumbnail,
      headers: ref.read(apiClientProvider)?.streamingHeaders,
      decodeWidth: mtDecodeWidth(context, thumbWidth, thumbHeight),
    );
    final platform = platformKindOf(MediaPlatform.detect(item.canonicalUrl));

    Future<void> toggleFavorite() async {
      final added = await actions.toggleFavorite(item.canonicalUrl);
      if (!context.mounted) return;
      showMTSnack(
        context,
        added ? l10n.addedToFavorites : l10n.removedFromFavorites,
      );
    }

    void onTap() => options.selecting
        ? controller.toggleSelected(item.canonicalUrl)
        : onPlay();
    void onLongPress() => controller.toggleSelected(item.canonicalUrl);
    void onMore() => showItemActionsSheet(context, ref, item);

    final duration = item.duration == null
        ? null
        : mtFormatDuration(item.duration!);
    if (columns case final columns?) {
      return MTMediaRow(
        columns: columns,
        title: item.title,
        subtitle: subtitle,
        thumbnail: thumbnail,
        platform: platform,
        duration: duration,
        size: item.sizeBytes == null ? null : mtFormatSize(item.sizeBytes!),
        added: item.timestamp == null
            ? null
            : mtTimeAgo(context, item.timestamp!),
        tags: item.tags,
        location: item.location,
        locationLabel: locationLabel,
        favorite: item.favorite,
        audio: item.isAudio,
        selected: options.selection.contains(item.canonicalUrl),
        highlighted: highlighted,
        onFavoriteToggle: toggleFavorite,
        onTap: onTap,
        onLongPress: onLongPress,
        onMore: onMore,
      );
    }
    if (options.grid || options.cards) {
      return MTMediaGridCard(
        feed: options.cards,
        title: item.title,
        subtitle: subtitle,
        thumbnail: thumbnail,
        platform: platform,
        location: item.location,
        locationLabel: locationLabel,
        duration: duration,
        favorite: item.favorite,
        audio: item.isAudio,
        selected: options.selection.contains(item.canonicalUrl),
        highlighted: highlighted,
        onFavoriteToggle: toggleFavorite,
        onTap: onTap,
        onLongPress: onLongPress,
        onMore: onMore,
      );
    }
    return MTMediaCard(
      title: item.title,
      subtitle: subtitle,
      thumbnail: thumbnail,
      platform: platform,
      location: item.location,
      locationLabel: locationLabel,
      compact: options.compact,
      favorite: item.favorite,
      audio: item.isAudio,
      selected: options.selection.contains(item.canonicalUrl),
      highlighted: highlighted,
      onFavoriteToggle: toggleFavorite,
      onTap: onTap,
      onLongPress: onLongPress,
      onMore: onMore,
    );
  }
}

/// The thumbnail box size in points for each mode, matching what `mt_ui`
/// draws (`MTMediaCard._Thumb` and `MTMediaGridCard._Cover`). The height is
/// `null` where the cover is 16:9, so its width alone determines the
/// decode.
(double, double?) _thumbBox(BuildContext context, LibraryViewMode mode) =>
    switch (mode) {
      LibraryViewMode.compact => (64, 40),
      LibraryViewMode.list => (98, 62),
      LibraryViewMode.grid => (210, null),
      // A tablet lays cards in columns, so none is ever wider than two of
      // the narrowest; a phone's card is the screen's width.
      LibraryViewMode.cards => (
        math.min(
          MediaQuery.sizeOf(context).width - MTSpace.pagePad * 2,
          MTBreakpoint.cardColumn * 2,
        ),
        null,
      ),
    };

extension LibraryLayoutOf on LibraryViewMode {
  MTLibraryLayout get layout => switch (this) {
    LibraryViewMode.list => MTLibraryLayout.list,
    LibraryViewMode.compact => MTLibraryLayout.compact,
    LibraryViewMode.grid => MTLibraryLayout.grid,
    LibraryViewMode.cards => MTLibraryLayout.cards,
  };
}
