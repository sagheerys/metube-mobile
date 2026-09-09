import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../library_providers.dart';
import '../local_item.dart';

/// The sort and view sheet: one button, with both choices saved.
void showSortSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const _SortSheet(),
  );
}

class _SortSheet extends ConsumerWidget {
  const _SortSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);

    final sortLabels = {
      LibrarySort.newest: l10n.sortNewest,
      LibrarySort.oldest: l10n.sortOldest,
      LibrarySort.nameAZ: l10n.sortNameAZ,
      LibrarySort.nameZA: l10n.sortNameZA,
      LibrarySort.largest: l10n.sortLargest,
      LibrarySort.smallest: l10n.sortSmallest,
    };

    return Padding(
      // The last option used to fall under the three navigation buttons
      // (field
      // report 2026-09-04); a sheet always reaches the screen edge.
      padding: EdgeInsets.fromLTRB(
        MTSpace.xl,
        MTSpace.lg,
        MTSpace.xl,
        mtSheetBottomPad(context, MTSpace.xxl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MTSectionHeader(title: l10n.sortBy),
          const SizedBox(height: MTSpace.md),
          Wrap(
            spacing: MTSpace.xs,
            runSpacing: MTSpace.xs,
            children: [
              for (final MapEntry(:key, :value) in sortLabels.entries)
                ChoiceChip(
                  label: Text(value),
                  selected: options.sort == key,
                  showCheckmark: false,
                  labelStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: options.sort == key
                        ? MTThemeX.of(context).palette.bg
                        : MTThemeX.of(context).palette.ink2,
                  ),
                  onSelected: (_) => controller.setSort(key),
                ),
            ],
          ),
          const SizedBox(height: MTSpace.xl),
          // **Four modes instead of overlapping flags**: compact and grid
          // were two
          // switches that could be on together meaninglessly, and a fourth
          // would
          // have doubled the impossible states. One choice prevents them at
          // the
          // root.
          MTSectionHeader(title: l10n.viewMode),
          const SizedBox(height: MTSpace.md),
          Wrap(
            spacing: MTSpace.xs,
            runSpacing: MTSpace.xs,
            children: [
              for (final (label, mode) in <(String, LibraryViewMode)>[
                (l10n.viewList, LibraryViewMode.list),
                (l10n.compactView, LibraryViewMode.compact),
                (l10n.viewGrid, LibraryViewMode.grid),
                (l10n.viewCards, LibraryViewMode.cards),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: options.mode == mode,
                  showCheckmark: false,
                  labelStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: options.mode == mode
                        ? MTThemeX.of(context).palette.bg
                        : MTThemeX.of(context).palette.ink2,
                  ),
                  onSelected: (_) => controller.setMode(mode),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
