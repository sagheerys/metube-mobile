import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../library_providers.dart';
import '../local_item.dart';

/// ورقة الفرز والعرض — زر واحد (النموذج أ)، والخياران محفوظان (م-14).
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
      padding: const EdgeInsets.fromLTRB(
          MTSpace.xl, MTSpace.lg, MTSpace.xl, MTSpace.xxl),
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
                  labelStyle: Theme.of(context)
                      .textTheme
                      .labelMedium!
                      .copyWith(
                          color: options.sort == key
                              ? MTThemeX.of(context).palette.bg
                              : MTThemeX.of(context).palette.ink2),
                  onSelected: (_) => controller.setSort(key),
                ),
            ],
          ),
          const SizedBox(height: MTSpace.xl),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.compactView,
                style: Theme.of(context).textTheme.bodyMedium),
            value: options.compact,
            onChanged: controller.setCompact,
          ),
        ],
      ),
    );
  }
}
