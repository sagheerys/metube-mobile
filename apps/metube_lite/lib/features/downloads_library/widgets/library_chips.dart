import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../library_providers.dart';
import '../local_item.dart';

/// رقاقة مرشح موحدة الشكل (مرجع «وهج»).
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: selectedColor,
      labelStyle: Theme.of(context)
          .textTheme
          .labelMedium!
          .copyWith(color: selected ? p.bg : p.ink2),
      onSelected: (_) => onTap(),
    );
  }
}

/// الصف الأول: الكل · ♥ المفضلة · فيديو · صوت · ⚡ قِصار (م-14/م-35/م-36).
class LibraryFilterChips extends ConsumerWidget {
  const LibraryFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);

    void toggleType(MediaTypeFilter type) => controller.setType(
        options.type == type ? MediaTypeFilter.all : type);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: l10n.filterAll,
            selected: options.scope == LocalScope.all,
            onTap: () => controller.setScope(LocalScope.all),
          ),
          const SizedBox(width: MTSpace.xs),
          // م-36: رقاقة المفضلة أول المرشحات بعد «الكل».
          _Chip(
            label: '♥ ${l10n.favorites}',
            selected: options.scope == LocalScope.favorites,
            selectedColor: p.favorite,
            onTap: () => controller.setScope(LocalScope.favorites),
          ),
          const SizedBox(width: MTSpace.md),
          _Chip(
            label: l10n.filterVideo,
            selected: options.type == MediaTypeFilter.video,
            onTap: () => toggleType(MediaTypeFilter.video),
          ),
          const SizedBox(width: MTSpace.xs),
          _Chip(
            label: l10n.filterAudio,
            selected: options.type == MediaTypeFilter.audio,
            onTap: () => toggleType(MediaTypeFilter.audio),
          ),
          const SizedBox(width: MTSpace.xs),
          _Chip(
            label: '⚡ ${l10n.shortsFilter}',
            selected: options.type == MediaTypeFilter.shorts,
            onTap: () => toggleType(MediaTypeFilter.shorts),
          ),
        ],
      ),
    );
  }
}

/// الصف الثاني: مرشح المنصة **بعدادات حية** (م-14 — خاص بـ Lite).
/// يختفي كلياً حين لا تكون في المكتبة أكثر من منصة واحدة.
class PlatformFilterChips extends ConsumerWidget {
  const PlatformFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final counts = ref.watch(platformCountsProvider);
    if (counts.length < 2) return const SizedBox.shrink();

    final selected = ref.watch(
        libraryViewProvider.select((options) => options.platform));
    final controller = ref.read(libraryViewProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: l10n.allPlatforms,
            selected: selected == null,
            onTap: () => controller.setPlatform(null),
          ),
          for (final MapEntry(:key, :value) in counts) ...[
            const SizedBox(width: MTSpace.xs),
            _Chip(
              label: l10n.platformCount(key.label, value),
              selected: selected == key,
              onTap: () =>
                  controller.setPlatform(selected == key ? null : key),
            ),
          ],
        ],
      ),
    );
  }
}
