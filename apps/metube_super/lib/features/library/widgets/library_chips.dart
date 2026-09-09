import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../playlists/playlists_providers.dart';
import '../library_models.dart';
import '../library_providers.dart';
import 'sort_sheet.dart';

/// The library filter row: all, favourites, offline, server, type,
/// shorts, with **the tag row** beneath it. Split out of
/// `library_screen.dart` for the size limit (rule 4).
class LibraryFilterChips extends ConsumerWidget {
  const LibraryFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);
    final x = MTThemeX.of(context);
    ChoiceChip chip(
      String label,
      bool selected,
      VoidCallback onTap, {
      Color? selectedColor,
    }) => ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: selectedColor,
      labelStyle: Theme.of(context).textTheme.labelMedium!
          .copyWith(color: selected ? x.palette.bg : x.palette.ink2),
      onSelected: (_) => onTap(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // **The chosen platform is seen and removed from here**
              // (requested
              // 2026-09-08): the choice is made in the sort sheet so no
              // third row
              // appears, but an active filter hidden behind a button makes
              // the library
              // look incomplete for no visible reason. The chip appears
              // only while the
              // filter is on.
              if (options.platform != null) ...[
                InputChip(
                  label: Text(options.platform!.label),
                  selected: true,
                  showCheckmark: false,
                  onDeleted: () => controller.setPlatform(null),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  deleteIconColor: x.palette.bg,
                  onPressed: () => showSortSheet(context, ref),
                  labelStyle: Theme.of(context).textTheme.labelMedium!
                      .copyWith(color: x.palette.bg),
                ),
                const SizedBox(width: MTSpace.xs),
              ],
              chip(
                l10n.filterAll,
                options.scope == LibraryScope.all,
                () => controller.setScope(LibraryScope.all),
              ),
              const SizedBox(width: MTSpace.xs),
              // The favourites chip is the first filter after "all".
              chip(
                '♥ ${l10n.favorites}',
                options.scope == LibraryScope.favorites,
                () => controller.setScope(LibraryScope.favorites),
                selectedColor: x.palette.favorite,
              ),
              const SizedBox(width: MTSpace.xs),
              chip(
                l10n.filterOffline,
                options.scope == LibraryScope.offline,
                () => controller.setScope(LibraryScope.offline),
              ),
              const SizedBox(width: MTSpace.xs),
              chip(
                l10n.filterServer,
                options.scope == LibraryScope.onServer,
                () => controller.setScope(LibraryScope.onServer),
              ),
              const SizedBox(width: MTSpace.md),
              // **Shorts in sight rather than past the edge** (device check
              // 2026-09-05): it is a whole path, and it was the last chip
              // in a row that needed a horizontal scroll with nothing to
              // hint at it.
              chip(
                '⚡ ${l10n.shortsFilter}',
                options.type == MediaTypeFilter.shorts,
                () => controller.setType(
                  options.type == MediaTypeFilter.shorts
                      ? MediaTypeFilter.all
                      : MediaTypeFilter.shorts,
                ),
              ),
              const SizedBox(width: MTSpace.xs),
              chip(
                l10n.filterVideo,
                options.type == MediaTypeFilter.video,
                () => controller.setType(
                  options.type == MediaTypeFilter.video
                      ? MediaTypeFilter.all
                      : MediaTypeFilter.video,
                ),
              ),
              const SizedBox(width: MTSpace.xs),
              chip(
                l10n.filterAudio,
                options.type == MediaTypeFilter.audio,
                () => controller.setType(
                  options.type == MediaTypeFilter.audio
                      ? MediaTypeFilter.all
                      : MediaTypeFilter.audio,
                ),
              ),
            ],
          ),
        ),
        const _TagFilterRow(),
      ],
    );
  }
}

/// **The tag row: compound filtering** (requested 2026-09-02).
///
/// The filter used to be a **single** tag arriving from the "your tags"
/// tab, with no way to combine. Now every tag is a chip with three states
/// cycled by tapping: neutral, included, excluded. Included tags are
/// combined with OR (widening) and excluded ones subtracted (narrowing), so
/// tapping alone covers every combination with no dropdown and no settings
/// screen.
class _TagFilterRow extends ConsumerWidget {
  const _TagFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts =
        ref.watch(tagCountsProvider).valueOrNull ?? const <String, int>{};
    if (counts.isEmpty) return const SizedBox.shrink();

    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);
    final p = MTThemeX.of(context).palette;
    final names = counts.keys.toList()..sort();
    final anyActive =
        options.tags.isNotEmpty || options.excludedTags.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: MTSpace.xs),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (anyActive) ...[
              ActionChip(
                avatar: Icon(Icons.backspace_outlined, size: 14, color: p.ink2),
                label: Text(l10n.clear),
                onPressed: controller.clearTags,
              ),
              const SizedBox(width: MTSpace.xs),
            ],
            for (final tag in names) ...[
              _TagChip(
                tag: tag,
                count: counts[tag] ?? 0,
                included: options.tags.contains(tag),
                excluded: options.excludedTags.contains(tag),
                onTap: () {
                  HapticFeedback.selectionClick();
                  controller.cycleTag(tag);
                },
              ),
              const SizedBox(width: MTSpace.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.count,
    required this.included,
    required this.excluded,
    required this.onTap,
  });

  final String tag;
  final int count;
  final bool included;
  final bool excluded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    // An exclusion is read before the text: a minus sign and a
    // strikethrough, in the error colour rather than the accent, so
    // subtraction is never mistaken for addition at a glance.
    final (bg, fg) = switch ((included, excluded)) {
      (true, _) => (p.accent, p.onAccent),
      (_, true) => (p.err.withValues(alpha: 0.14), p.err),
      _ => (Colors.transparent, p.ink2),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTRadius.chip),
        side: BorderSide(color: excluded ? p.err : p.line2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MTRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MTSpace.md,
            vertical: MTSpace.xs,
          ),
          child: Text(
            // "# Ai 45" rendered with the number before the name; isolation
            // pins it.
            mtLtrRun('${excluded ? '− ' : '# '}$tag  $count'),
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: fg,
              decoration: excluded ? TextDecoration.lineThrough : null,
              decorationColor: fg,
            ),
          ),
        ),
      ),
    );
  }
}
