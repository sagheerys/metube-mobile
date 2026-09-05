import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../library/library_providers.dart';
import '../library/widgets/item_details_sheet.dart';
import '../player/playback_providers.dart';

/// شاشة الصوت الكاملة في Super (`/audio`) — المحتوى من mt_media،
/// وتفاصيل المقطع من طبقة التطبيق (mt_media لا يعرف فهارس المكتبة).
class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    return MTAudioScreen(
      handler: handler,
      artwork: artworkBuilderFor(ref),
      // **زر التفاصيل بدل زر القائمة** (بلاغ المالك 2026-09-05):
      // القائمة لها زرها الظاهر أسفل الشاشة.
      onDetails: () => _showDetails(context, ref, handler),
    );
  }

  void _showDetails(
      BuildContext context, WidgetRef ref, MTAudioHandler handler) {
    final key = handler.currentItem?.canonicalUrl;
    if (key == null) return;
    final items = ref.read(libraryItemsProvider).valueOrNull ?? const [];
    for (final candidate in items) {
      if (candidate.canonicalUrl == key) {
        showItemDetailsSheet(context, candidate);
        return;
      }
    }
  }
}
