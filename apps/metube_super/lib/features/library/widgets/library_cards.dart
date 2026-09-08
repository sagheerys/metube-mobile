import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';
import '../../home/add_flow.dart';
import '../artwork_view.dart';
import '../library_actions.dart';
import '../library_models.dart';
import '../library_providers.dart';
import 'item_actions_sheet.dart';

/// بطاقة عنصر المكتبة — **مصدر واحد لأوضاع العرض الأربعة**.
///
/// فُصلت عن `library_screen.dart` عند إضافة العرض الشبكي (القاعدة 4):
/// نسختان من نفس المنطق كانتا ستفترقان عند أول تعديل، ولن يتذكر أحد أن
/// شارة «دون اتصال» تُضبط في مكانين.
///
/// الوضع يُقرأ من الخيارات مباشرة لا من معامل: الشاشة كانت تمرّر
/// `grid: true` والبطاقة تقرأ `compact` من المزوّد — مصدران لقرار واحد.
class LibraryItemCard extends ConsumerWidget {
  const LibraryItemCard({
    super.key,
    required this.item,
    required this.onPlay,
  });

  final LibraryItem item;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final controller = ref.read(libraryViewProvider.notifier);
    final actions = ref.read(libraryActionsProvider);
    // **تقدّم السحب كان يُحسب ولا يعرضه أحد** (بلاغ المالك 2026-09-02:
    // «لا يظهر العداد، يبدو كأنه لا يستجيب») — سواء من «حفظ للجهاز»
    // أو من المشاركة التي تسحب نسخة مؤقتة أولاً.
    final pulling = ref.watch(offlinePullProgressProvider)[item.canonicalUrl];
    final highlighted =
        ref.watch(highlightedItemProvider) == item.canonicalUrl;

    final subtitle = pulling != null
        ? '${l10n.pullingToDevice} ${(pulling * 100).round()}٪'
        : [
            if (item.uploader != null) item.uploader!,
            if (item.timestamp != null) mtTimeAgo(context, item.timestamp!),
          ].join(' · ');
    final locationLabel = switch (item.location) {
      MTMediaLocation.offline ||
      MTMediaLocation.both =>
        l10n.availabilityOffline,
      MTMediaLocation.onServer => l10n.filterServer,
      MTMediaLocation.none => null,
    };
    // **الفك عند حجم العرض لا حجم الأصل**: مصغرة 1280×720 في صندوق
    // 98 نقطة كانت تحجز ~3.5MB لكل بطاقة مرئية في ذاكرة الصور.
    final (thumbWidth, thumbHeight) = _thumbBox(context, options.mode);
    final thumbnail = artworkFor(item.thumbnail,
        headers: ref.read(apiClientProvider)?.streamingHeaders,
        decodeWidth: mtDecodeWidth(context, thumbWidth, thumbHeight));
    final platform = platformKindOf(MediaPlatform.detect(item.canonicalUrl));

    Future<void> toggleFavorite() async {
      final added = await actions.toggleFavorite(item.canonicalUrl);
      if (!context.mounted) return;
      showMTSnack(
        context,
        added ? l10n.addedToFavorites : l10n.removedFromFavorites,
      );
    }

    void onTap() => options.selecting
        ? controller.toggleSelected(item.canonicalUrl)
        : onPlay();
    void onLongPress() => controller.toggleSelected(item.canonicalUrl);
    void onMore() => showItemActionsSheet(context, ref, item);

    if (options.grid || options.cards) {
      return MTMediaGridCard(
        feed: options.cards,
        title: item.title,
        subtitle: subtitle,
        thumbnail: thumbnail,
        platform: platform,
        location: item.location,
        locationLabel: locationLabel,
        duration: item.duration == null
            ? null
            : mtFormatDuration(item.duration!),
        favorite: item.favorite,
        selected: options.selection.contains(item.canonicalUrl),
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
      platform: platform,
      location: item.location,
      locationLabel: locationLabel,
      compact: options.compact,
      favorite: item.favorite,
      selected: options.selection.contains(item.canonicalUrl),
      highlighted: highlighted,
      onFavoriteToggle: toggleFavorite,
      onTap: onTap,
      onLongPress: onLongPress,
      onMore: onMore,
    );
  }
}

/// مقاس صندوق المصغرة بالنقاط لكل وضع — مطابق لما ترسمه `mt_ui`
/// (`MTMediaCard._Thumb` و`MTMediaGridCard._Cover`). الارتفاع `null`
/// حيث الغلاف 16:9، فعرضه وحده يحدد الفك.
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
