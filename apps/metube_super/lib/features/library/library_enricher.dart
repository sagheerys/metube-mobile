import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show ServerStreamEndpoint;

import '../../di.dart';
import 'library_models.dart';
import 'library_providers.dart';
import 'media_probe.dart';

/// **إثراء مكتبة Super (م-18 + م-35).**
///
/// سيرفر المالك لا يرجع حقل `thumbnail` لأي عنصر (صفر من 252)، والأبعاد
/// كانت تُتعلَّم **عند أول تشغيل فقط** — فمكتبة السيرفر كلها بلا أغلفة
/// وخارج «مسار القِصار» (بلاغ المالك: «الريلز لا تعمل إلا إذا شغّلتها
/// أول مرة، والمصغرات لا تظهر»).
///
/// المصدر: النسخة المحلية إن وُجدت (أسرع وبلا شبكة)، وإلا **بثّ
/// السيرفر** — القارئ الأصلي يقرأ الترويسة بطلبات نطاق ولا ينزّل الملف.
class LibraryEnricher {
  LibraryEnricher(this._ref, {this.batchSize = 8, MediaProbe? probe})
      : _probe = probe ?? const MediaProbe();

  final Ref _ref;
  final MediaProbe _probe;

  /// دفعة أصغر من Lite: كل عنصر هنا قد يعني رحلة شبكة.
  final int batchSize;

  final Set<String> _seen = {};
  bool _running = false;

  Future<void> enrich(List<LibraryItem> items) async {
    if (_running) return;
    final endpoint = _ref.read(playbackResolverProvider).endpoint;
    final headers = _ref.read(apiClientProvider)?.streamingHeaders ?? const {};

    // **ترتيب السبر = ترتيب العرض** (مصطاد على المحاكي 2026-09-02):
    // كان يسبر بترتيب `/history` بينما تعرض المكتبة الأحدث أولاً، فمرّت
    // دقائق و٥٥ غلافاً جاهزاً ولا شيء منها في أول الشاشة. والمحلي قبل
    // الشبكي دائماً: قراءة ملف على القرص أرخص من رحلة للسيرفر.
    final candidates = [
      for (final item in items)
        if (_needsProbe(item)) item,
    ]..sort((a, b) {
        final localFirst = (b.localPath != null ? 1 : 0) -
            (a.localPath != null ? 1 : 0);
        if (localFirst != 0) return localFirst;
        final at = a.timestamp, bt = b.timestamp;
        if (at == null || bt == null) return 0;
        return bt.compareTo(at); // الأحدث أولاً
      });

    final pending = <ProbeRequest>[];
    for (final item in candidates) {
      final request = _requestFor(item, endpoint);
      if (request != null) pending.add(request);
    }
    if (pending.isEmpty) return;

    _running = true;
    try {
      for (var i = 0; i < pending.length; i += batchSize) {
        final batch = pending.skip(i).take(batchSize).toList();
        _seen.addAll(batch.map((r) => r.key));
        final results = await _probe.probe(batch, headers: headers);
        if (await _apply(results)) {
          _ref.invalidate(libraryItemsProvider);
        }
      }
    } finally {
      _running = false;
    }
  }

  bool _needsProbe(LibraryItem item) =>
      !_seen.contains(item.canonicalUrl) &&
      (item.thumbnail == null ||
          item.duration == null ||
          (!item.isAudio && item.aspectRatio == null));

  /// المحلي أولاً؛ وإلا رابط البث. عنصر بلا الاثنين لا يُسبَر.
  ProbeRequest? _requestFor(LibraryItem item, ServerStreamEndpoint endpoint) {
    if (item.localPath != null) {
      return ProbeRequest(key: item.canonicalUrl, path: item.localPath);
    }
    final filename = item.serverFilename;
    if (filename == null) return null;
    try {
      return ProbeRequest(key: item.canonicalUrl, url: endpoint.buildUrl(filename));
    } on UnsafeFilenameException {
      // القاعدة 9: اسم ملف خبيث لا يُبنى له رابط أبداً.
      return null;
    }
  }

  Future<bool> _apply(List<ProbedMedia> results) async {
    final shapes = _ref.read(mediaShapeIndexProvider);
    final artwork = _ref.read(artworkIndexProvider);
    final existing = await artwork.readAll();
    var changed = false;

    for (final probed in results) {
      if (probed.isEmpty) continue;
      if (probed.duration != null) {
        await shapes.remember(
          probed.key,
          probed.duration!,
          probed.aspectRatio ?? 1,
        );
        changed = true;
      }
      // لا نطمس غلافاً موجوداً (غلاف يوتيوب المشتق أدق من لقطة إطار).
      if (probed.thumbPath != null && existing[probed.key] == null) {
        await artwork.put(probed.key, probed.thumbPath!);
        changed = true;
      }
    }
    return changed;
  }
}

final libraryEnricherProvider =
    Provider<LibraryEnricher>((ref) => LibraryEnricher(ref));

/// يشتغل كلما تغيّرت المكتبة ويتوقف وحده حين لا يبقى ما ينقصه.
final libraryEnrichmentProvider = Provider<void>((ref) {
  final items = ref.watch(libraryItemsProvider).valueOrNull;
  if (items == null || items.isEmpty) return;
  unawaited(ref.read(libraryEnricherProvider).enrich(items));
});
