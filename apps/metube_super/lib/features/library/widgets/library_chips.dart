import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../library_models.dart';
import '../library_providers.dart';

/// صف مرشحات المكتبة (م-14/م-36/م-37): الوسم النشط ← الكل ← المفضلة ←
/// دون اتصال ← الخادم ← النوع ← ⚡ القِصار.
/// فُصل عن `library_screen.dart` لحدّ الأسطر (القاعدة 4).
class LibraryFilterChips extends ConsumerWidget {
  const LibraryFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);
    final x = MTThemeX.of(context);
    ChoiceChip chip(String label, bool selected, VoidCallback onTap,
            {Color? selectedColor}) =>
        ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: selectedColor,
          labelStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: selected ? x.palette.bg : x.palette.ink2),
          onSelected: (_) => onTap(),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // وسم نشط قادم من تبويب «وسومك» — نقرته تلغيه (م-37/ج).
          if (options.tag != null) ...[
            InputChip(
              label: Text('# ${options.tag}'),
              selected: true,
              showCheckmark: false,
              selectedColor: x.palette.offlineSoft,
              onDeleted: () => controller.setTag(null),
              onSelected: (_) => controller.setTag(null),
            ),
            const SizedBox(width: MTSpace.xs),
          ],
          chip(l10n.filterAll, options.scope == LibraryScope.all,
              () => controller.setScope(LibraryScope.all)),
          const SizedBox(width: MTSpace.xs),
          // م-36: رقاقة المفضلة أول المرشحات بعد «الكل».
          chip('♥ ${l10n.favorites}',
              options.scope == LibraryScope.favorites,
              () => controller.setScope(LibraryScope.favorites),
              selectedColor: x.palette.favorite),
          const SizedBox(width: MTSpace.xs),
          chip(l10n.filterOffline, options.scope == LibraryScope.offline,
              () => controller.setScope(LibraryScope.offline)),
          const SizedBox(width: MTSpace.xs),
          chip(l10n.filterServer, options.scope == LibraryScope.onServer,
              () => controller.setScope(LibraryScope.onServer)),
          const SizedBox(width: MTSpace.md),
          chip(l10n.filterVideo, options.type == MediaTypeFilter.video,
              () => controller.setType(
                  options.type == MediaTypeFilter.video
                      ? MediaTypeFilter.all
                      : MediaTypeFilter.video)),
          const SizedBox(width: MTSpace.xs),
          chip(l10n.filterAudio, options.type == MediaTypeFilter.audio,
              () => controller.setType(
                  options.type == MediaTypeFilter.audio
                      ? MediaTypeFilter.all
                      : MediaTypeFilter.audio)),
          const SizedBox(width: MTSpace.xs),
          // م-35: رقاقة «⚡ قِصار» تجمع العمودية القصيرة.
          chip('⚡ ${l10n.shortsFilter}',
              options.type == MediaTypeFilter.shorts,
              () => controller.setType(
                  options.type == MediaTypeFilter.shorts
                      ? MediaTypeFilter.all
                      : MediaTypeFilter.shorts)),
        ],
      ),
    );
  }
}
