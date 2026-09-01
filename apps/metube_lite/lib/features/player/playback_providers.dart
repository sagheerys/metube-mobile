import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../downloads_library/artwork_view.dart';
import '../downloads_library/library_providers.dart';
import '../downloads_library/local_item.dart';
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
final playbackRequestProvider = StateProvider<PlaybackRequest?>((ref) => null);

/// جلسة الفيديو — تُبنى عند فتح المشغل وتُصرَّف عند مغادرته. تسجّل أبعاد
/// كل مقطع تشغّله في `media_shape_index` فتتراكم معرفة «القِصار» (م-35).
final videoSessionProvider = Provider.autoDispose<MTVideoSession>((ref) {
  final session = MTVideoSession(
    resolver: ref.watch(playbackResolverProvider),
    positions: ref.watch(playbackPositionsProvider),
    prefs: ref.watch(playbackPrefsProvider),
  );
  final shapes = ref.watch(mediaShapeIndexProvider);
  session.onShapeKnown = (key, duration, aspectRatio) async {
    await shapes.remember(key, duration, aspectRatio);
    ref.invalidate(localMediaProvider);
  };
  // **مخرج صوت واحد.** فتح فيديو والصوت الخلفي يعمل كان يشغّل الاثنين
  // معاً (خلل مصطاد على جهاز المالك).
  session.onTakeAudioFocus = ref.read(audioHandlerProvider).pause;
  ref.onDispose(session.dispose);
  return session;
});

/// تحويل عنصر المكتبة المحلية إلى عنصر تشغيل موحد.
///
/// [PlaylistItem.canonicalUrl] هنا هو **مفتاح العنصر** (رابط أو مسار)
/// لأنه مفتاح الاستئناف والمفضلة والقوائم في Lite. و[serverFilename]
/// يبقى null دائماً: لا بث في Lite — الملف المحلي هو المصدر الوحيد.
PlaylistItem toPlaylistItem(LocalItem item) => PlaylistItem(
      canonicalUrl: item.key,
      title: item.title,
      artworkUrl: item.thumbnail,
      localPath: item.path,
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
              cachedTitle: item.title,
              cachedThumb: item.artworkUrl,
            ),
        ],
      );
  ref.invalidate(playlistsProvider);
  return true;
}

/// باني المصغرات للمشغلات (م-18): أغلفة المنصات المحفوظة في فهرس
/// الأغلفة — بلا ترويسات مصادقة (لا شيء منها من سيرفر العائلة).
MTArtworkBuilder artworkBuilderFor(WidgetRef ref) => (context, item) =>
    artworkFor(item.artworkUrl) ?? const SizedBox.shrink();

/// المنصة المعروضة لعنصر تشغيل — مفتاحه قد يكون مساراً لا رابطاً.
MediaPlatform platformOfKey(String key) =>
    key.startsWith('http') ? MediaPlatform.detect(key) : MediaPlatform.other;
