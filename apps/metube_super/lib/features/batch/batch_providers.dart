import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import 'batch_offline_saver.dart';

/// معاينة قائمة (م-11): YouTube عبر InnerTube مباشرة (الحزمة الجاهزة
/// كانت تعيد صفر عناصر — بلاغ 2026-09-02) وSoundCloud عبر الـ resolver
/// الهش المعزول — أي فشل يظهر رسالة ولا يكسر شيئاً.
final playlistPreviewProvider =
    FutureProvider.family<PlaylistPreview?, String>((ref, url) async {
  final preview = switch (PlaylistDetector.detect(url)) {
    PlaylistKind.youtube => await YoutubePlaylistResolver().resolve(url),
    PlaylistKind.soundcloud => await SoundCloudResolver().resolveSet(url),
    PlaylistKind.none => null,
  };
  if (preview == null) {
    // م-32: سبب الشاشة الفارغة يجب أن يبقى أثراً — لا أن يتبخر.
    unawaited(ref
        .read(loggerProvider)
        .error('playlist resolve failed', tag: 'playlist'));
  }
  return preview;
});

/// إدراج المحدد في طابور المحرك (ر-3 خطوة 2) — العناصر تدخل خلف أي
/// مفرد جارٍ وتُعلَّم كأعضاء دفعة.
final batchSubmitterProvider = Provider((ref) => BatchSubmitter(ref));

class BatchSubmitter {
  const BatchSubmitter(this._ref);

  final Ref _ref;

  /// يعيد عدد ما أُدرج فعلاً (0 = لا سيرفر مُعد).
  ///
  /// **[groupName] يجمع الدفعة في قائمة محفوظة واحدة** (سؤال المالك
  /// 2026-09-02): قبله كانت عناصر الدورة الواحدة تتناثر في المكتبة بلا
  /// أي رابط بينها. التجميع يحدث عند اكتمال كل عنصر، بترتيب المصدر.
  ///
  /// **[saveToDevice]** يطبّق «إتاحة دون اتصال» (م-17) على كل عضو يكتمل
  /// — الأصل يبقى على السيرفر (ر-2 محفوظة).
  int submit(
    List<String> urls,
    Quality quality, {
    String? groupName,
    bool saveToDevice = false,
  }) {
    final engine = _ref.read(downloadEngineProvider);
    if (engine == null || urls.isEmpty) return 0;
    final ids = [
      for (final url in urls)
        engine.submit(url, quality, isBatchMember: true).id,
    ];
    if (groupName != null && groupName.trim().isNotEmpty) {
      unawaited(_ref.read(batchCollectorProvider).begin(groupName.trim(), ids));
    }
    if (saveToDevice) _ref.read(batchOfflineSaverProvider).want(ids);
    return ids.length;
  }
}
