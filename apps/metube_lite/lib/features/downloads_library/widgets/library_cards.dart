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

/// بطاقة عنصر المكتبة في Lite — **مصدر واحد للقائمة والشبكة**.
///
/// فُصلت عن `library_screen.dart` عند نقل العرض الشبكي من Super (طلب
/// المالك 2026-09-04) بنفس قرار Super: نسختان من المنطق نفسه تفترقان
/// عند أول تعديل. الملف نظير `apps/metube_super/.../library_cards.dart`
/// — أي تعديل هنا يُنظر في نظيره (قاعدة «التطبيقان» في CLAUDE.md).
class LibraryItemCard extends ConsumerWidget {
  const LibraryItemCard({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onClearHighlight,
    this.grid = false,
  });

  final LocalItem item;
  final VoidCallback onPlay;

  /// الإبراز مؤقت بطبعه: أي نقرة تُطفئه فوراً وإلا بقي العنصر «محدداً»
  /// للأبد (بلاغ المالك 2026-09-02).
  final VoidCallback onClearHighlight;
  final bool grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);
    final actions = ref.read(libraryActionsProvider);
    final highlighted = ref.watch(highlightedItemProvider) == item.key;

    final subtitle = [
      mtTimeAgo(context, item.modified),
      '${(item.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
    ].join(' · ');

    Future<void> toggleFavorite() async {
      final added = await actions.toggleFavorite(item.key);
      if (!context.mounted) return;
      showMTSnack(context,
          added ? l10n.addedToFavorites : l10n.removedFromFavorites);
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

    if (grid) {
      return MTMediaGridCard(
        title: item.title,
        subtitle: subtitle,
        thumbnail: item.thumbnail == null ? null : artworkFor(item.thumbnail),
        platform: platformKindOf(item.platform),
        duration:
            item.duration == null ? null : mtFormatDuration(item.duration!),
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
      thumbnail: item.thumbnail == null ? null : artworkFor(item.thumbnail),
      platform: platformKindOf(item.platform),
      // **لا شارة موقع في Lite** (بلاغ المالك 2026-09-02): كل عنصر في
      // هذه المكتبة ملف على الجهاز بحكم بنائها من مسح المجلد، فـ«بلا
      // اتصال» على كل بطاقة معلومة صفرية وضجيج بصري. الشارة تبقى في
      // Super حيث يتعايش المحلي والسيرفري.
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
