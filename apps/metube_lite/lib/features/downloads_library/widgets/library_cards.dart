import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_ui/mt_ui.dart';

import '../../home/add_flow.dart' show platformKindOf;
import '../artwork_view.dart';
import '../library_actions.dart';
import '../library_providers.dart';
import '../local_item.dart';
import 'item_actions_sheet.dart';

/// Lite's library item card: **one source for all four view modes**.
///
/// Split out of `library_screen.dart` when the grid view came over from
/// Super (requested 2026-09-04), by the same reasoning as Super: two copies
/// of the same logic diverge at the first edit. This file is the
/// counterpart of `apps/metube_super/.../library_cards.dart`, and any
/// change here is considered for its twin.
class LibraryItemCard extends ConsumerWidget {
  const LibraryItemCard({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onClearHighlight,
  });

  final LocalItem item;
  final VoidCallback onPlay;

  /// The highlight is temporary by nature: any tap extinguishes it at once,
  /// or the item stays looking "selected" forever (field report
  /// 2026-09-02).
  final VoidCallback onClearHighlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);
    final actions = ref.read(libraryActionsProvider);
    final highlighted = ref.watch(highlightedItemProvider) == item.key;

    // **Decode at display size, not at original size**: a 1280x720
    // thumbnail
    // in a 98-point box reserved about 3.5MB per visible card in the image
    // cache.
    final (thumbWidth, thumbHeight) = _thumbBox(context, options.mode);
    final thumbnail = artworkFor(
      item.thumbnail,
      decodeWidth: mtDecodeWidth(context, thumbWidth, thumbHeight),
    );

    final subtitle = [
      mtTimeAgo(context, item.modified),
      '${(item.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
    ].join(' · ');

    Future<void> toggleFavorite() async {
      final added = await actions.toggleFavorite(item.key);
      if (!context.mounted) return;
      showMTSnack(
        context,
        added ? l10n.addedToFavorites : l10n.removedFromFavorites,
      );
    }

    void onTap() {
      if (options.selecting) {
        controller.toggleSelected(item.key);
        return;
      }
      if (highlighted) onClearHighlight();
      onPlay();
    }

    void onLongPress() => controller.toggleSelected(item.key);
    void onMore() => showItemActionsSheet(context, ref, item);

    if (options.grid || options.cards) {
      return MTMediaGridCard(
        feed: options.cards,
        title: item.title,
        subtitle: subtitle,
        thumbnail: thumbnail,
        platform: platformKindOf(item.platform),
        duration: item.duration == null
            ? null
            : mtFormatDuration(item.duration!),
        favorite: item.favorite,
        selected: options.selection.contains(item.key),
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
      platform: platformKindOf(item.platform),
      // **No location badge in Lite** (field report 2026-09-02): every item
      // in this library is a file on the device, because the library is
      // built by scanning the folder, so "offline" on every card carries no
      // information and is visual noise. The badge stays in Super, where
      // local and server items coexist.
      compact: options.compact,
      favorite: item.favorite,
      selected: options.selection.contains(item.key),
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
