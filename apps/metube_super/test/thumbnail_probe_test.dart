import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_enricher.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/media_probe.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/shared/error_report.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

/// **حرّاس عطل المصغرات (قياس على جهاز المالك 2026-09-07).**
///
/// مكتبة السيرفر كانت بلا مصغرات إلا ليوتيوب (وهي مشتقّة من المعرّف لا
/// مسبورة). السبب المقيس: **سجلٌّ واحد** في `/history` لملف حُذف من قرص
/// السيرفر (١ من ٢٦٩) — وتسليمُ رابطه إلى `MediaMetadataRetriever` يجعل
/// منصة أندرويد تعيد المحاولة **عشراً بمهلة 8s**، فتتجمّد بقية العناصر
/// خلفه أكثر من ٨٠ ثانية في كل جلسة. والإخفاق كان يُبتلع بصمت.
void main() {
  late MemoryKeyValueStore store;
  late MTLogger logger;
  late File logFile;

  const item = LibraryItem(
    canonicalUrl: 'https://instagram.com/reel/abc',
    title: 'Video by someone',
    serverFilename: 'Video by someone.mp4',
    onServer: true,
  );

  setUp(() {
    store = MemoryKeyValueStore();
    logFile = File(
        '${Directory.systemTemp.path}/mtf_probe_${DateTime.now().microsecondsSinceEpoch}.log');
    logger = MTLogger(filePath: logFile.path);
    clearErrorSignature('probe');
  });

  tearDown(() async {
    try {
      if (await logFile.exists()) await logFile.delete();
    } on FileSystemException {
      // ويندوز قد يقفله لحظة كتابة متأخرة.
    }
  });

  ProviderContainer containerWith(int status, MediaProbe probe) {
    final dio = Dio()..httpClientAdapter = _StatusAdapter(status);
    final api = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'https://srv.example.com'),
      dio: dio,
    );
    return ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      initialSettingsProvider.overrideWithValue(
          const SuperSettings(activeUrl: 'https://srv.example.com')),
      loggerProvider.overrideWithValue(logger),
      apiClientProvider.overrideWithValue(api),
      playbackResolverProvider.overrideWithValue(PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.fromApi(api),
        fileExists: (_) => false,
      )),
    ]);
  }

  test('ملف مفقود على السيرفر ⇒ لا يُسلَّم للمنصة أصلاً، ويُسجَّل سببه',
      () async {
    final probe = _RecordingProbe();
    final container = containerWith(404, probe);
    addTearDown(container.dispose);

    await LibraryEnricher(container.read(_refProvider), probe: probe)
        .enrich(const [item]);

    // **الحارس الأول**: بلا الفحص المسبق كان الرابط الميت يذهب إلى
    // `MediaMetadataRetriever` فيجمّد الطابور ٨٠ ثانية.
    expect(probe.calls, isEmpty,
        reason: 'رابط ميت لا يُسلَّم للمنصة');

    // **الحارس الثاني**: الإخفاق يُكتب — كان يُبتلع بصمت تاماً.
    expect(await logger.readAll(), contains('file missing on server'));

    // **الحارس الثالث**: يُؤجَّل يوماً فلا يُعاد كل إقلاع.
    final failures = await container.read(probeFailureIndexProvider).readAll();
    expect(failures.containsKey(item.canonicalUrl), isTrue);
  });

  test('عنصر أخفق قريباً يُتخطّى ولو عاد الملف', () async {
    final index = ProbeFailureIndex(store: store, mutex: PrefsMutex());
    await index.put(item.canonicalUrl, DateTime.now());

    final probe = _RecordingProbe();
    final container = containerWith(206, probe); // السيرفر سليم الآن
    addTearDown(container.dispose);

    await LibraryEnricher(container.read(_refProvider), probe: probe)
        .enrich(const [item]);

    expect(probe.calls, isEmpty, reason: 'التبريد يمنع إعادة المحاولة فوراً');
  });

  test('ملف موجود ⇒ يُسبَر فعلاً', () async {
    final probe = _RecordingProbe();
    final container = containerWith(206, probe);
    addTearDown(container.dispose);

    await LibraryEnricher(container.read(_refProvider), probe: probe)
        .enrich(const [item]);

    expect(probe.calls, hasLength(1));
    expect(probe.calls.single.single.url, contains('/download/'));
  });

  test('التبريد ينتهي بعد يوم', () {
    final index = ProbeFailureIndex(store: store, mutex: PrefsMutex());
    final old = DateTime.now().subtract(const Duration(days: 2));
    expect(index.isCoolingDown({'k': old}, 'k'), isFalse);
    expect(index.isCoolingDown({'k': DateTime.now()}, 'k'), isTrue);
  });

  test('غلافٌ اختفى من القرص ⇒ يُنسى ويُعاد سبره', () async {
    final artwork = ArtworkIndex(store: store, mutex: PrefsMutex());
    // مسار في مجلد كاش مُسح — هذا ما فعله أندرويد بمصغرات المالك.
    await artwork.put(item.canonicalUrl, '/data/cache/thumbs/gone.jpg');

    final probe = _RecordingProbe();
    final container = containerWith(206, probe);
    addTearDown(container.dispose);

    // العنصر يحمل غلافاً في نموذجه، فبلا التنظيف لا يُرشَّح للسبر أبداً.
    const withThumb = LibraryItem(
      canonicalUrl: 'https://instagram.com/reel/abc',
      title: 'Video by someone',
      serverFilename: 'Video by someone.mp4',
      onServer: true,
      thumbnail: '/data/cache/thumbs/gone.jpg',
      duration: Duration(seconds: 30),
      aspectRatio: 0.5625,
    );
    await LibraryEnricher(container.read(_refProvider), probe: probe)
        .enrich(const [withThumb]);

    expect(probe.calls, hasLength(1), reason: 'يُعاد سبره في نفس الجولة');
    // المسار الميت زال، وحلّ محلّه ما أعطاه السبر الجديد.
    expect((await artwork.readAll())[item.canonicalUrl],
        isNot('/data/cache/thumbs/gone.jpg'));
  });
}

/// وصول إلى `Ref` من داخل الحاوية — `LibraryEnricher` يأخذ `Ref` لا حاوية.
final _refProvider = Provider<Ref>((ref) => ref);

class _RecordingProbe extends MediaProbe {
  _RecordingProbe();

  final calls = <List<ProbeRequest>>[];

  @override
  Future<List<ProbedMedia>> probe(
    List<ProbeRequest> requests, {
    Map<String, String> headers = const {},
  }) async {
    calls.add(requests);
    return [
      for (final r in requests)
        ProbedMedia(
          key: r.key,
          duration: const Duration(seconds: 30),
          width: 1080,
          height: 1920,
          thumbPath: '/cache/${r.key.hashCode}.jpg',
        ),
    ];
  }
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromBytes(utf8.encode(status == 404 ? 'no' : 'x'),
        status, headers: {
      't': ['application/octet-stream'],
    });
  }

  @override
  void close({bool force = false}) {}

}
