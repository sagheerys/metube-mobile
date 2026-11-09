import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../playlists/add_to_playlist_sheet.dart';
import '../library_actions.dart';
import '../library_providers.dart';
import '../local_item.dart';
import 'downloads_sheet.dart';
import 'item_actions_sheet.dart';
import 'sort_sheet.dart';

/// The library's bar: its name and three buttons, or **the search field in
/// the name's place** once the search button is pressed (mobile plan
/// 2026-11-01), which leaves the list a row higher on every visit. The
/// field stays while a query is written, so a narrowed list never looks
/// unexplained; the back arrow clears it.
AppBar libraryMainBar(
  BuildContext context,
  WidgetRef ref, {
  required int activeCount,
  required bool searching,
  required VoidCallback onSearch,
  required VoidCallback onCloseSearch,
}) {
  final l10n = context.mtl;
  if (searching) {
    return AppBar(
      leading: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: onCloseSearch,
        icon: const BackButtonIcon(),
      ),
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsetsDirectional.only(end: MTSpace.pagePad),
        child: MTQuerySearchField(
          hint: l10n.searchVideos,
          query: ref.watch(libraryViewProvider.select((o) => o.query)),
          onChanged: ref.read(libraryViewProvider.notifier).setQuery,
          autofocus: true,
        ),
      ),
    );
  }
  return AppBar(
    title: Text(l10n.navMyDownloads),
    actions: [
      IconButton(
        tooltip: MaterialLocalizations.of(context).searchFieldLabel,
        onPressed: onSearch,
        icon: const MTIcon(MTIcons.search),
      ),
      // The active downloads badge, which opens the management sheet.
      IconButton(
        tooltip: l10n.activeDownloadsSheet,
        onPressed: () => showDownloadsSheet(context),
        icon: MTDownloadsIcon(active: activeCount),
      ),
      // A dot while a platform chosen inside the sheet is on.
      MTFilterButton(
        tooltip: l10n.sortAndPlatform,
        active: ref.watch(
          libraryViewProvider.select((o) => o.platform != null),
        ),
        onPressed: () => showSortSheet(context, ref),
      ),
    ],
  );
}

/// The bar while clips are selected: how many, and what to do with them.
AppBar librarySelectionBar(
  BuildContext context,
  WidgetRef ref,
  LibraryViewOptions options,
) {
  final l10n = context.mtl;

  /// The library items matching the current selection.
  List<LocalItem> selected() {
    final visible = ref.read(visibleLibraryProvider).valueOrNull ?? const [];
    return [
      for (final item in visible)
        if (options.selection.contains(item.key)) item,
    ];
  }

  final controller = ref.read(libraryViewProvider.notifier);
  final selection = options.selection;
  return AppBar(
    leading: IconButton(
      onPressed: controller.clearSelection,
      icon: const MTIcon(MTIcons.close),
    ),
    // The count rises to its new value rather than jumping.
    title: MTAnimatedSwap(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        l10n.selectedCount(selection.length),
        key: ValueKey(selection.length),
      ),
    ),
    actions: [
      IconButton(
        tooltip: l10n.selectAll,
        onPressed: () {
          final items = ref.read(visibleLibraryProvider).valueOrNull ?? [];
          controller.selectAll(items.map((i) => i.key));
        },
        icon: const MTIcon(MTIcons.selectAll),
      ),
      IconButton(
        tooltip: l10n.addToPlaylist,
        onPressed: () => showAddToPlaylistSheet(context, ref, selected()),
        icon: const MTIcon(MTIcons.queueAdd),
      ),
      IconButton(
        tooltip: l10n.shareSelected,
        onPressed: () =>
            ref.read(libraryActionsProvider).share(context, selected()),
        icon: const MTIcon(MTIcons.share),
      ),
      IconButton(
        tooltip: l10n.deleteSelected,
        onPressed: () => confirmBulkDelete(context, ref, selection),
        icon: MTIcon(MTIcons.trash, color: MTThemeX.of(context).palette.err),
      ),
    ],
  );
}
