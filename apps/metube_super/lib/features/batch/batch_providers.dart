import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';

/// معاينة قائمة (م-11): YouTube عبر youtube_explode وSoundCloud عبر
/// الـ resolver الهش المعزول — أي فشل يظهر رسالة ولا يكسر شيئاً.
final playlistPreviewProvider =
    FutureProvider.family<PlaylistPreview?, String>((ref, url) async {
  return switch (PlaylistDetector.detect(url)) {
    PlaylistKind.youtube => YoutubePlaylistResolver().resolve(url),
    PlaylistKind.soundcloud => SoundCloudResolver().resolveSet(url),
    PlaylistKind.none => null,
  };
});

/// إدراج المحدد في طابور المحرك (ر-3 خطوة 2) — العناصر تدخل خلف أي
/// مفرد جارٍ وتُعلَّم كأعضاء دفعة.
final batchSubmitterProvider = Provider((ref) => BatchSubmitter(ref));

class BatchSubmitter {
  const BatchSubmitter(this._ref);

  final Ref _ref;

  /// يعيد عدد ما أُدرج فعلاً (0 = لا سيرفر مُعد).
  int submit(List<String> urls, Quality quality) {
    final engine = _ref.read(downloadEngineProvider);
    if (engine == null || urls.isEmpty) return 0;
    for (final url in urls) {
      engine.submit(url, quality, isBatchMember: true);
    }
    return urls.length;
  }
}
