import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../library/artwork_view.dart';
import '../library/library_models.dart';
import '../library/library_providers.dart';

/// طلب تشغيل معلّق: القائمة المعروضة وقت النقر بترتيبها وتصفيتها (ر-4).
class PlaybackRequest {
  const PlaybackRequest({
    required this.items,
    required this.startIndex,
    this.playlistId,
    this.playlistName,
  });

  final List<PlaylistItem> items;
  final int startIndex;
  final String? playlistId;
  final String? playlistName;
}

/// يوضع قبل الانتقال إلى `/player` ثم تقرؤه الشاشة مرة واحدة.
final playbackRequestProvider =
    StateProvider<PlaybackRequest?>((ref) => null);

/// جلسة الفيديو — تُبنى عند فتح المشغل وتُصرَّف عند مغادرته.
/// تسجّل أبعاد كل مقطع تشغّله في `media_shape_index` فتتراكم معرفة
/// «القِصار» بلا طلب إضافي من السيرفر (م-35).
final videoSessionProvider = Provider.autoDispose<MTVideoSession>((ref) {
  final session = MTVideoSession(
    resolver: ref.watch(playbackResolverProvider),
    positions: ref.watch(playbackPositionsProvider),
    prefs: ref.watch(playbackPrefsProvider),
  );
  final shapes = ref.watch(mediaShapeIndexProvider);
  // **علم الحياة قبل الإبطال (إصلاح م-6):** `remember` تنتظر القرص، وقد
  // يُغلق المشغل خلالها فيُصرَّف هذا المزوّد (autoDispose) ⇒ `StateError`
  // في السجل عند كل إغلاق سريع.
  var alive = true;
  ref.onDispose(() => alive = false);
  session.onShapeKnown = (url, duration, aspectRatio) async {
    await shapes.remember(url, duration, aspectRatio);
    if (alive) ref.invalidate(libraryItemsProvider);
  };
  // **مخرج صوت واحد — بالاتجاهين.** فتح فيديو والصوت الخلفي يعمل كان
  // يشغّل الاثنين معاً (خلل مصطاد على جهاز المالك)، وبقي الاتجاه
  // المعاكس مفتوحاً حتى العطل ع-4: زر التشغيل في إشعار الوسائط — أو
  // تشغيل صوتيات من شاشة القوائم المفتوحة فوق المشغل — كان يعزف فوق
  // الفيديو العامل.
  final handler = ref.read(audioHandlerProvider);
  session.onTakeAudioFocus = handler.pause;
  // **يُمسح تسجيلنا وحده** (2026-09-03): الريلز يسجّل موقِفه أيضاً، وشطب
  // التسجيل بلا تمييز كان يترك الطرف الحي بلا حماية فيعزف مصدران معاً.
  final pauseVideo = session.pause;
  handler.onTakeVideoFocus = pauseVideo;
  ref.onDispose(() {
    if (handler.onTakeVideoFocus == pauseVideo) {
      handler.onTakeVideoFocus = null;
    }
    unawaited(session.dispose());
  });
  return session;
});

/// تحويل عنصر المكتبة إلى عنصر تشغيل موحد (المفتاح canonicalUrl).
PlaylistItem toPlaylistItem(LibraryItem item) => PlaylistItem(
      canonicalUrl: item.canonicalUrl,
      title: item.title,
      uploader: item.uploader,
      artworkUrl: item.thumbnail,
      localPath: item.localPath,
      serverFilename: item.serverFilename,
      isAudio: item.isAudio,
      duration: item.duration,
      aspectRatio: item.aspectRatio,
    );


/// باني المصغرات للمشغلات — الصور البعيدة بترويسات المصادقة (م-18).
/// **الترويسات تُقرأ عند كل بناء صورة لا مرة واحدة (إصلاح م-9):**
/// التقاطها في الإغلاق كان يُبقي اعتمادات السيرفر القديم بعد التبديل
/// التلقائي، فتفشل الأغلفة بـ401 حتى إعادة بناء الشاشة.
MTArtworkBuilder artworkBuilderFor(WidgetRef ref) => (context, item) =>
    artworkFor(item.artworkUrl,
        headers: ref.read(apiClientProvider)?.streamingHeaders);
