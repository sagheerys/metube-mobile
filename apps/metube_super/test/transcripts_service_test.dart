import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/transcripts/transcripts_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

/// **Searching inside clips, the Super side** (2026-09-30): the transcript
/// is fetched before each YouTube clip is added, kept on the phone, and
/// never shown in the library as a clip of its own.
void main() {
  const id = 'jNQXAC9IVRw';
  const watch = 'https://www.youtube.com/watch?v=$id';

  late Directory temp;
  late _FakeServer server;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('mtf_transcripts_super');
    server = _FakeServer()
      ..texts['Me at the zoo [$id].ar.srt'] =
          '1\n00:00:01,000 --> 00:00:02,000\nhere we are\n'
      ..texts['Me at the zoo [$id].en.srt'] =
          '1\n00:00:01,000 --> 00:00:02,000\nthe elephants\n';
  });
  tearDown(() => temp.deleteSync(recursive: true));

  Future<ProviderContainer> container({
    bool enabled = true,
    String localeCode = 'ar',
  }) async {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          SuperSettings(localeCode: localeCode),
        ),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${temp.path}/log.txt'),
        ),
        transcriptsRootProvider.overrideWith(
          (ref) async => Directory('${temp.path}/transcripts'),
        ),
        captionsFetcherFactoryProvider.overrideWithValue(
          (api) => CaptionsFetcher(api, wait: (_) async {}),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(transcriptsEnabledProvider.future);
    if (enabled) await c.read(transcriptsEnabledProvider.notifier).set(true);
    return c;
  }

  DownloadTask task(String url, {bool batch = false}) =>
      DownloadTask(inputUrl: url, quality: Quality.best, isBatchMember: batch);

  test('off by default: the server is not even asked', () async {
    final c = await container(enabled: false);
    await c
        .read(transcriptsServiceProvider)
        .fetchBeforeAdd(task(watch), server);

    expect(server.historyReads, 0);
    expect(Directory('${temp.path}/transcripts').existsSync(), isFalse);
  });

  test('on: a YouTube clip has its transcript kept and searchable', () async {
    final c = await container();
    await c
        .read(transcriptsServiceProvider)
        .fetchBeforeAdd(task('https://youtu.be/$id'), server);

    expect(server.captionsAsked, [
      '$watch ar',
      '$watch en',
    ], reason: 'the app language first, then English');
    final store = await c.read(transcriptStoreProvider.future);
    expect(
      (await store.read(watch, 'ar'))!.segments.single.text,
      'here we are',
    );
    expect(
      (await store.read(watch, 'en'))!.segments.single.text,
      'the elephants',
    );
    expect(server.historyReads, greaterThan(0));
    final index = await c.read(transcriptIndexProvider.future);
    expect(index.search('here we').single.canonicalUrl, watch);
    expect((await c.read(transcriptStatsProvider.future)).clips, 1);
  });

  test('in English, English alone: a second language adds nothing', () async {
    final c = await container(localeCode: 'en');
    await c
        .read(transcriptsServiceProvider)
        .fetchBeforeAdd(task('https://youtu.be/$id'), server);

    expect(server.captionsAsked, ['$watch en']);
    final store = await c.read(transcriptStoreProvider.future);
    expect(await store.read(watch, 'ar'), isNull);
    expect(
      (await store.read(watch, 'en'))!.segments.single.text,
      'the elephants',
    );
  });

  test('playlists, their members and other sites are left alone', () async {
    final c = await container();
    final service = c.read(transcriptsServiceProvider);
    await service.fetchBeforeAdd(task(watch, batch: true), server);
    await service.fetchBeforeAdd(
      task(
        'https://www.youtube.com/playlist?list=PL590L5WQmH8fJ54F369BLDSqIwcs-TCfs',
      ),
      server,
    );
    await service.fetchBeforeAdd(task('https://vimeo.com/76979871'), server);

    expect(server.historyReads, 0);
  });

  test('while off, transcripts on disk are not even read', () async {
    final c = await container(enabled: false);
    await TranscriptStore(Directory('${temp.path}/transcripts')).write(
      Transcript(
        canonicalUrl: watch,
        language: 'ar',
        source: 'captions',
        fetchedAt: DateTime.utc(2026),
        segments: const [
          TranscriptSegment(
            start: Duration.zero,
            end: Duration(seconds: 1),
            text: 'x',
          ),
        ],
      ),
    );
    expect((await c.read(transcriptIndexProvider.future)).length, 0);
  });

  test('export, delete, import: nothing lost', () async {
    final c = await container();
    final service = c.read(transcriptsServiceProvider);
    await service.fetchBeforeAdd(task(watch), server);
    final exported = await service.exportAll();

    await service.deleteAll();
    expect((await c.read(transcriptIndexProvider.future)).length, 0);
    expect(Directory('${temp.path}/transcripts').existsSync(), isFalse);

    expect(await service.importAll(exported), 2, reason: 'both languages');
    expect(
      (await c.read(transcriptIndexProvider.future))
          .search('here')
          .single
          .canonicalUrl,
      watch,
    );
    expect(await service.importAll('{"app": "MTF", "prefs": {}}'), isNull);
  });

  test('the history the screens read never holds a subtitles job', () async {
    final api = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'https://srv.example.com'),
      dio: Dio()
        ..httpClientAdapter = _HistoryAdapter({
          'done': [
            {'url': watch, 'download_type': 'video', 'status': 'finished'},
            {'url': watch, 'download_type': 'captions', 'status': 'finished'},
          ],
          'queue': [],
        }),
    );
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${temp.path}/log.txt'),
        ),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(c.dispose);

    final history = await c.read(historyProvider.future);
    expect(history!.done.map((i) => i.downloadType), ['video']);
  });

  test("transcripts stay out of Google's cloud backup", () {
    // Its ceiling is 25MB for the whole app: passing it stops the backup
    // of every setting, silently.
    final legacy = File('android/app/src/main/res/xml/backup_rules.xml')
        .readAsStringSync();
    final modern = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();
    const rule = '<exclude domain="file" path="transcripts/"/>';

    expect(legacy, contains(rule));
    final cloud = modern.substring(
      modern.indexOf('<cloud-backup>'),
      modern.indexOf('</cloud-backup>'),
    );
    expect(cloud, contains(rule));
  });
}

/// A MeTube server that answers subtitles jobs at once: each finishes as a
/// `done` entry named for its language, and is gone once deleted.
class _FakeServer implements MeTubeApi {
  int historyReads = 0;
  final captionsAsked = <String>[];
  final texts = <String, String>{};
  final _done = <Map<String, Object>>[];

  @override
  Future<HistoryResponse> fetchHistory() async {
    historyReads++;
    return HistoryResponse.fromJson({'done': _done, 'queue': []});
  }

  @override
  Future<void> addCaptions(String url, {required String language}) async {
    captionsAsked.add('$url $language');
    _done.add({
      'url': url,
      'download_type': 'captions',
      'status': 'finished',
      'filename': 'Me at the zoo [jNQXAC9IVRw].$language.srt',
    });
  }

  @override
  Future<String> fetchText(String serverFilename, {int maxBytes = 0}) async =>
      texts[serverFilename] ?? (throw const NoApiException());

  @override
  Future<void> delete(
    List<String> canonicalUrls, {
    String where = 'done',
  }) async => _done.removeWhere((e) => canonicalUrls.contains(e['url']));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _HistoryAdapter implements HttpClientAdapter {
  _HistoryAdapter(this.body);

  final Map<String, Object> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
