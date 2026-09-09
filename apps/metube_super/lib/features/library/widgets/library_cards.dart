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
  const LibraryItemCard({super.key, required this.item, required this.onPlay});

  final LibraryItem item;
  final VoidCallback onPlay;

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
        ? '${l10n.pullingToDevice} ${(pulling * 100).round()}٪'
        : [
            if (item.uploader != null) item.uploader!,
            if (item.timestamp != null) mtTimeAgo(context, item.timestamp!),
          ].join(' · ');
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
    final (thumbWidth, thumbHeight) = _thumbBox(context, options.mode);
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

    if (options.grid || options.cards) {
      return MTMediaGridCard(
        feed: options.cards,
        title: item.title,
        subtitle: subtitle,
        thumbnail: thumbnail,
        platform: platform,
        location: item.location,
        locationLabel: locationLabel,
        duration: item.duration == null
            ? null
            : mtFormatDuration(item.duration!),
        favorite: item.favorite,
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
      LibraryViewMode.cards => (
        MediaQuery.sizeOf(context).width - MTSpace.pagePad * 2,
        null,
      ),
    };
