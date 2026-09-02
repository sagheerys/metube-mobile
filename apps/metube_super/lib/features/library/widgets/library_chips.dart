import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../playlists/playlists_providers.dart';
import '../library_models.dart';
import '../library_providers.dart';

/// صف مرشحات المكتبة (م-14/م-36/م-37): الكل ← المفضلة ← دون اتصال ←
/// الخادم ← النوع ← ⚡ القِصار، ثم **صف الوسوم** تحته.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
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
        ),
        const _TagFilterRow(),
      ],
    );
  }
}

/// **صف الوسوم — تصفية مركبة** (طلب المالك 2026-09-02).
///
/// كان المرشح وسماً **واحداً** يأتي من تبويب «وسومك» ولا يمكن تركيبه.
/// الآن كل وسم رقاقة بثلاث حالات تدور بالنقر: محايد ← مُضمَّن ← مُستثنى.
/// المضمَّنة تُجمع بـ«أو» (توسيع)، والمستثناة تُطرح (تضييق) — فيغطي
/// النقر وحده كل التركيبات بلا قائمة منسدلة ولا شاشة إعدادات.
class _TagFilterRow extends ConsumerWidget {
  const _TagFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(tagCountsProvider).value ?? const <String, int>{};
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
                avatar: Icon(Icons.backspace_outlined,
                    size: 14, color: p.ink2),
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
    // الاستثناء يُقرأ قبل النص: «−» وشطب، ولون الخطأ لا لون الفعل — كي
    // لا يُخلط الطرح بالجمع في نظرة واحدة.
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
              horizontal: MTSpace.md, vertical: MTSpace.xs),
          child: Text(
            '${excluded ? '− ' : '# '}$tag  $count',
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: fg,
                  decoration:
                      excluded ? TextDecoration.lineThrough : null,
                  decorationColor: fg,
                ),
          ),
        ),
      ),
    );
  }
}
