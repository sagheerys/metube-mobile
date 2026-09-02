import 'dart:async';

import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../library/artwork_view.dart';
import '../library/library_models.dart';
import '../library/library_providers.dart';
import '../playlists/playlists_providers.dart';

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
  session.onShapeKnown = (url, duration, aspectRatio) async {
    await shapes.remember(url, duration, aspectRatio);
    ref.invalidate(libraryItemsProvider);
  };
  // **مخرج صوت واحد — بالاتجاهين.** فتح فيديو والصوت الخلفي يعمل كان
  // يشغّل الاثنين معاً (خلل مصطاد على جهاز المالك)، وبقي الاتجاه
  // المعاكس مفتوحاً حتى العطل ع-4: زر التشغيل في إشعار الوسائط — أو
  // تشغيل صوتيات من شاشة القوائم المفتوحة فوق المشغل — كان يعزف فوق
  // الفيديو العامل.
  final handler = ref.read(audioHandlerProvider);
  session.onTakeAudioFocus = handler.pause;
  handler.onTakeVideoFocus = session.pause;
  ref.onDispose(() {
    handler.onTakeVideoFocus = null;
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

/// م-38: تحويل جلسة التشغيل الحالية لقائمة دائمة.
Future<bool> saveQueueAsPlaylist(
  WidgetRef ref,
  String name,
  List<PlaylistItem> items,
) async {
  if (name.isEmpty || items.isEmpty) return false;
  await ref.read(playlistsStoreProvider).create(
        name,
        items: [
          for (final item in items)
            PlaylistEntry(
              canonicalUrl: item.canonicalUrl,
              serverFilename: item.serverFilename,
              cachedTitle: item.title,
              cachedThumb: item.artworkUrl,
            ),
        ],
      );
  ref.invalidate(playlistsProvider);
  return true;
}

/// باني المصغرات للمشغلات — الصور البعيدة بترويسات المصادقة (م-18).
MTArtworkBuilder artworkBuilderFor(WidgetRef ref) {
  final headers = ref.read(apiClientProvider)?.streamingHeaders;
  return (context, item) =>
      artworkFor(item.artworkUrl, headers: headers) ?? const SizedBox.shrink();
}
