import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../downloads_library/library_providers.dart';
import '../downloads_library/widgets/item_details_sheet.dart';
import '../player/playback_providers.dart';

/// شاشة الصوت الكاملة (`/audio`) — المحتوى من mt_media، والمصغرات
/// وتفاصيل المقطع من طبقة التطبيق (mt_media لا يعرف فهارس المكتبة).
class AudioScreen extends ConsumerWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    return MTAudioScreen(
      handler: handler,
      artwork: artworkBuilderFor(ref),
      // **بلا رقاقة مصدر في Lite** (بلاغ المالك 2026-09-04): «تشغيل من
      // جهازك» معلومة صفرية هنا — لا يوجد في مكتبة Lite غير الجهاز.
      showSourceChip: false,
      // **زر التفاصيل بدل زر القائمة** (بلاغ المالك 2026-09-05):
      // القائمة لها زرها الظاهر أسفل الشاشة.
      onDetails: () => _showDetails(context, ref, handler),
    );
  }

  void _showDetails(
      BuildContext context, WidgetRef ref, MTAudioHandler handler) {
    final key = handler.currentItem?.canonicalUrl;
    if (key == null) return;
    final items = ref.read(localMediaProvider).value ?? const [];
    for (final candidate in items) {
      if (candidate.key == key) {
        showItemDetailsSheet(context, candidate);
        return;
      }
    }
  }
}
