import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
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
  session.onShapeKnown = (url, duration, aspectRatio) async {
    await shapes.remember(url, duration, aspectRatio);
    ref.invalidate(libraryItemsProvider);
  };
  ref.onDispose(session.dispose);
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
MTArtworkBuilder artworkBuilderFor(WidgetRef ref) {
  final headers = ref.read(apiClientProvider)?.streamingHeaders;
  return (context, item) {
    final url = item.artworkUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => const SizedBox.shrink(),
    );
  };
}
