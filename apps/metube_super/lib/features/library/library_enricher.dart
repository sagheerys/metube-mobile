import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show ServerStreamEndpoint;

import '../../di.dart';
import '../shared/error_report.dart';
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

    // **غلافٌ في الفهرس لا يعني ملفاً على القرص**: المصغرات كانت تُكتب
    // في `cacheDir` وأندرويد يمسحه تحت ضغط التخزين، فبقيت البطاقات
    // فارغة **ولا تُعاد أبداً** لأن `_needsProbe` يرى غلافاً مسجّلاً.
    final stale = await _forgetMissingThumbs();

    // **ترتيب السبر = ترتيب العرض** (مصطاد على المحاكي 2026-09-02):
    // كان يسبر بترتيب `/history` بينما تعرض المكتبة الأحدث أولاً، فمرّت
    // دقائق و٥٥ غلافاً جاهزاً ولا شيء منها في أول الشاشة. والمحلي قبل
    // الشبكي دائماً: قراءة ملف على القرص أرخص من رحلة للسيرفر.
    final candidates = [
      for (final item in items)
        if (_needsProbe(item) || stale.contains(item.canonicalUrl)) item,
    ]..sort((a, b) {
        final localFirst = (b.localPath != null ? 1 : 0) -
            (a.localPath != null ? 1 : 0);
        if (localFirst != 0) return localFirst;
        final at = a.timestamp, bt = b.timestamp;
        if (at == null || bt == null) return 0;
        return bt.compareTo(at); // الأحدث أولاً
      });

    // **ذاكرة الإخفاق** (عطل 2026-09-07): عنصر أخفق قريباً لا يُعاد
    // سبره — سجلٌّ واحد ميت كان يستهلك ٨٠ ثانية من كل جلسة.
    final failures = _ref.read(probeFailureIndexProvider);
    final cooling = await failures.readAll();

    // **غلافٌ في الفهرس لا يعني ملفاً على القرص**: المصغرات كانت تُكتب
    // في `cacheDir` وأندرويد يمسحه تحت ضغط التخزين، فبقيت البطاقات
    // فارغة **ولا تُعاد أبداً** لأن `_needsProbe` يرى غلافاً مسجّلاً.
    final pending = <ProbeRequest>[];
    for (final item in candidates) {
      if (failures.isCoolingDown(cooling, item.canonicalUrl)) continue;
      final request = _requestFor(item, endpoint);
      if (request == null) continue;
      // **لا يُسلَّم للمنصة رابطٌ لم نتأكد من حياته**: `MediaMetadata‑
      // Retriever` يعيد المحاولة عشراً بمهلة 8s على الرابط الميت
      // ويجمّد الطابور، بينما بايت واحد منّا يحسمها بجزء من ثانية.
      if (request.url != null && !await _serverHasFile(item)) {
        await _recordFailure(item.canonicalUrl, 'file missing on server');
        continue;
      }
      pending.add(request);
    }
    // عدّاد الطابور في السجل: «لا مصغرات» له ثلاثة أسباب متشابهة في
    // الشكل (لا مرشحين · كلها مبرَّدة · كلها بلا اسم ملف)، وبلا هذا
    // السطر لا يفرّق بينها أحد.
    unawaited(_ref.read(loggerProvider).log(
        'probe queue: ${pending.length} of ${candidates.length} '
        '(cooling ${cooling.length})',
        tag: 'library'));
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

  /// يمسح من فهرس الأغلفة كل مسارٍ لم يعد له ملف، ويعيد مفاتيحه كي
  /// تُسبَر من جديد في نفس الجولة.
  Future<Set<String>> _forgetMissingThumbs() async {
    final artwork = _ref.read(artworkIndexProvider);
    final all = await artwork.readAll();
    final gone = <String>{
      for (final entry in all.entries)
        // روابط الشبكة (ytimg) ليست ملفات — تُترك كما هي.
        if (!entry.value.startsWith('http') && !File(entry.value).existsSync())
          entry.key,
    };
    for (final key in gone) {
      await artwork.removeKey(key);
    }
    if (gone.isNotEmpty) {
      unawaited(_ref.read(loggerProvider).log(
          'thumbs vanished from disk: ${gone.length}',
          tag: 'library'));
    }
    return gone;
  }

  /// بايت واحد بمهلة قصيرة — عبر عميل النواة وحده (القاعدة 1).
  Future<bool> _serverHasFile(LibraryItem item) async {
    final api = _ref.read(apiClientProvider);
    final filename = item.serverFilename;
    if (api == null || filename == null) return false;
    return api.fileExists(filename);
  }

  /// يسجّل السبب في السجل التشخيصي **ويؤجّل** إعادة المحاولة يوماً.
  Future<void> _recordFailure(String canonicalUrl, String reason) async {
    // يُنتظر هنا (خلافاً للواجهة): الإثراء عمل خلفي لا يعطّل شاشة،
    // وترتيب السجل أهم من ميلي ثانية.
    await logErrorOnce(
      _ref.read(loggerProvider),
      'probe',
      '$reason ($canonicalUrl)',
      tag: 'library',
    );
    await _ref.read(probeFailureIndexProvider).put(canonicalUrl, DateTime.now());
  }

  Future<bool> _apply(List<ProbedMedia> results) async {
    final shapes = _ref.read(mediaShapeIndexProvider);
    final artwork = _ref.read(artworkIndexProvider);
    final existing = await artwork.readAll();
    var changed = false;

    for (final probed in results) {
      if (probed.error != null) {
        await _recordFailure(probed.key, probed.error!);
      }
      if (probed.isEmpty) {
        // بلا خطأ صريح ولا بيانات: ترميز لم تفهمه المنصة — إخفاق كذلك.
        if (probed.error == null) {
          await _recordFailure(probed.key, 'probe returned nothing');
        }
        continue;
      }
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
