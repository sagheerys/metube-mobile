import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart' show MediaPlatform;
import 'package:mt_ui/mt_ui.dart';

import '../library_models.dart';
import '../library_providers.dart';

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

    // **قابلة للتمرير**: الورقة صارت ثلاثة أقسام، وعلى شاشة قصيرة أو
    // بخط نظام مكبّر كان آخرها يتجاوز ارتفاع الورقة بلا مخرج.
    return SingleChildScrollView(
      child: Padding(
        // آخر خيار كان يقع تحت أزرار التنقل الثلاثة (بلاغ المالك
        // 2026-09-04) — الورقة تمتد لحافة الشاشة دائماً.
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
                    labelStyle: Theme.of(context).textTheme.labelMedium!
                        .copyWith(
                          color: options.sort == key
                              ? MTThemeX.of(context).palette.bg
                              : MTThemeX.of(context).palette.ink2,
                        ),
                    onSelected: (_) => controller.setSort(key),
                  ),
              ],
            ),
            const SizedBox(height: MTSpace.xl),
            const _PlatformSection(),
            // **أربعة أوضاع بدل أعلام متداخلة**: «مضغوط» و«شبكي» كانا
            // مفتاحين يمكن تشغيلهما معاً بلا معنى، والرابع كان سيضاعف
            // الحالات المستحيلة. الاختيار الواحد يمنعها من أصلها.
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
                    labelStyle: Theme.of(context).textTheme.labelMedium!
                        .copyWith(
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
      ),
    );
  }
}

/// **مرشح المنصة داخل الورقة لا في صفٍّ ثالث** (طلب المالك 2026-09-08).
///
/// Lite يعرضه صفَّ رقائق تحت المرشحات، لكن مكتبة Super فوقها صف مرشحات
/// **وصف وسوم** أصلاً — وثالثٌ كان سيدفع أول بطاقة خارج الشاشة. فالخيار
/// هنا، والمنصة المختارة تظهر رقاقةً قابلة للإزالة في الصف الأول كي لا
/// تكون تصفيةٌ فعّالة مخبوءة خلف زر.
///
/// يختفي القسم كلياً حين لا تكون في المكتبة أكثر من منصة واحدة.
class _PlatformSection extends ConsumerWidget {
  const _PlatformSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(platformCountsProvider);
    if (counts.length < 2) return const SizedBox.shrink();

    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final selected = ref.watch(
      libraryViewProvider.select((options) => options.platform),
    );
    final controller = ref.read(libraryViewProvider.notifier);

    Widget chip(String label, bool on, MediaPlatform? target) => ChoiceChip(
      label: Text(label),
      selected: on,
      showCheckmark: false,
      labelStyle: Theme.of(context).textTheme.labelMedium!
          .copyWith(color: on ? p.bg : p.ink2),
      onSelected: (_) => controller.setPlatform(target),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MTSectionHeader(title: l10n.platform),
        const SizedBox(height: MTSpace.md),
        Wrap(
          spacing: MTSpace.xs,
          runSpacing: MTSpace.xs,
          children: [
            chip(l10n.allPlatforms, selected == null, null),
            for (final MapEntry(:key, :value) in counts)
              chip(
                l10n.platformCount(key.label, value),
                selected == key,
                selected == key ? null : key,
              ),
          ],
        ),
        const SizedBox(height: MTSpace.xl),
      ],
    );
  }
}
