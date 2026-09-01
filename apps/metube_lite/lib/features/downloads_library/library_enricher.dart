import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import 'library_providers.dart';
import 'local_item.dart';
import 'media_probe.dart';

/// **إثراء المكتبة المحلية (م-18 + م-35).**
///
/// المكتبة تُبنى من مسح المجلد، فالملف المهاجَر من Lite القديم يصل بلا
/// غلاف ولا أبعاد. قبل هذا الإثراء كانت الأبعاد تُتعلَّم **عند أول تشغيل
/// فقط** — فمكتبة المالك (194 ملفاً) كانت كلها خارج «مسار القِصار» حتى
/// يشغّل كل مقطع بيده مرة، وكلها بلا مصغرات.
///
/// يعمل على دفعات ويُبطل المكتبة بعد كل دفعة، فتظهر المصغرات تباعاً بدل
/// انتظار المسح كله.
class LibraryEnricher {
  LibraryEnricher(this._ref, {this.batchSize = 20, MediaProbe? probe})
      : _probe = probe ?? const MediaProbe();

  final Ref _ref;
  final MediaProbe _probe;
  final int batchSize;

  /// ما سُبر في هذه الجلسة — ملف لم يعطِ شيئاً (تالف) لا يُعاد سبره في
  /// كل بناء للمكتبة، ولا يُخزَّن على القرص: إعادة المحاولة بعد إعادة
  /// التشغيل رخيصة وقد ينجح ما فشل.
  final Set<String> _seen = {};
  bool _running = false;

  /// يسبر ما ينقصه غلاف أو أبعاد. آمن للاستدعاء المتكرر.
  Future<void> enrich(List<LocalItem> items) async {
    if (_running) return;
    final pending = [
      for (final item in items)
        if (_needsProbe(item)) item,
    ];
    if (pending.isEmpty) return;

    _running = true;
    try {
      for (var i = 0; i < pending.length; i += batchSize) {
        final batch = pending.skip(i).take(batchSize).toList();
        _seen.addAll(batch.map((item) => item.path));
        final results = await _probe.probe([
          for (final item in batch) item.path,
        ]);
        if (await _apply(batch, results)) {
          _ref.invalidate(localMediaProvider);
        }
      }
    } finally {
      _running = false;
    }
  }

  bool _needsProbe(LocalItem item) =>
      !_seen.contains(item.path) &&
      (item.thumbnail == null ||
          item.duration == null ||
          (!item.isAudio && item.aspectRatio == null));

  /// يكتب النتائج في الفهرسين بمفتاح العنصر الموحّد. true ⇔ تغيّر شيء.
  Future<bool> _apply(
    List<LocalItem> batch,
    List<ProbedMedia> results,
  ) async {
    final byPath = {for (final probed in results) probed.path: probed};
    final shapes = _ref.read(mediaShapeIndexProvider);
    final artwork = _ref.read(artworkIndexProvider);
    var changed = false;

    for (final item in batch) {
      final probed = byPath[item.path];
      if (probed == null || probed.isEmpty) continue;
      // المفتاح هو canonicalUrl إن عُرف وإلا المسار — نفس قاعدة المكتبة.
      if (probed.duration != null) {
        await shapes.remember(
          item.key,
          probed.duration!,
          probed.aspectRatio ?? item.aspectRatio ?? 1,
        );
        changed = true;
      }
      if (item.thumbnail == null && probed.thumbPath != null) {
        await artwork.put(item.key, probed.thumbPath!);
        changed = true;
      }
    }
    return changed;
  }
}

final libraryEnricherProvider =
    Provider<LibraryEnricher>((ref) => LibraryEnricher(ref));

/// يشتغل تلقائياً كلما تغيّرت المكتبة — يُراقَب من غلاف التطبيق مرة.
/// يتوقف وحده: الدورة التالية لا تجد ما ينقصه فلا تُبطل شيئاً.
final libraryEnrichmentProvider = Provider<void>((ref) {
  final items = ref.watch(localMediaProvider).value;
  if (items == null || items.isEmpty) return;
  unawaited(ref.read(libraryEnricherProvider).enrich(items));
});
