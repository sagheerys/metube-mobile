import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/transcripts/sidecar_backfill.dart';
import 'package:metube_super/features/transcripts/transcripts_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

/// **What a subscription brings gets its transcript too** (2026-10-02):
/// the subtitle file a server writes beside each clip is read in the
/// background, once per file, and only while the transcripts are on.
void main() {
  const vtt =
      'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nhere we are\n'
      '\n00:00:03.000 --> 00:00:04.000\nthe elephants\n';

  LibraryItem onServer(String id, {String ext = 'mp4', DateTime? at}) =>
      LibraryItem(
        canonicalUrl: 'https://www.youtube.com/watch?v=$id',
        title: id,
        serverFilename: '$id.$ext',
        onServer: true,
        timestamp: at,
      );

  late Directory temp;
  late _FakeServer server;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('mtf_sidecar_super');
    server = _FakeServer();
  });
  tearDown(() => temp.deleteSync(recursive: true));

  Future<ProviderContainer> container({
    bool enabled = true,
    Object? serverError,
  }) async {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          const SuperSettings(localeCode: 'ar'),
        ),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${temp.path}/log.txt'),
        ),
        sidecarApiProvider.overrideWithValue(server),
        libraryServerErrorProvider.overrideWithValue(serverError),
        transcriptsRootProvider.overrideWith(
          (ref) async => Directory('${temp.path}/transcripts'),
        ),
        sidecarBackfillProvider.overrideWith(
          (ref) => SidecarBackfill(ref, pause: Duration.zero),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(transcriptsEnabledProvider.future);
    if (enabled) await c.read(transcriptsEnabledProvider.notifier).set(true);
    return c;
  }

  test('GUARD: while off, the server is not asked for a single file', () async {
    server.texts['a.ar.vtt'] = vtt;
    final c = await container(enabled: false);
    await c.read(sidecarBackfillProvider).run([onServer('a')]);

    expect(server.asked, isEmpty);
    expect(Directory('${temp.path}/transcripts').existsSync(), isFalse);
  });

  test('a clip with a file beside it becomes searchable', () async {
    server.texts['a.ar.vtt'] = vtt;
    final c = await container();
    await c.read(sidecarBackfillProvider).run([onServer('a')]);

    final index = await c.read(transcriptIndexProvider.future);
    expect(
      index.search('elephants').single.canonicalUrl,
      'https://www.youtube.com/watch?v=a',
    );
    expect(server.asked, [
      'a.ar.vtt',
      'a.en.vtt',
      'a.en.srt',
    ], reason: 'the app language, then English, each by its two names');
    expect((await c.read(transcriptStatsProvider.future)).clips, 1);
  });

  test(
    'GUARD: a miss is remembered across runs, until the file changes',
    () async {
      final c = await container();
      final backfill = c.read(sidecarBackfillProvider);
      await backfill.run([onServer('a')]);
      final firstRun = server.asked.length;
      expect(firstRun, 4, reason: 'two languages by two names');

      // A fresh walker, as after a relaunch: nothing is asked again.
      c.invalidate(sidecarBackfillProvider);
      final again = c.read(sidecarBackfillProvider);
      expect(again, isNot(same(backfill)));
      await again.run([onServer('a')]);
      expect(server.asked.length, firstRun);

      // Downloaded again to a new file: checked once more.
      await again.run([onServer('a', ext: 'webm')]);
      expect(server.asked.length, firstRun + 4);
    },
  );

  test('a clip that already has a transcript is left alone', () async {
    final c = await container();
    await c
        .read(transcriptsServiceProvider)
        .save(
          Transcript(
            canonicalUrl: 'https://www.youtube.com/watch?v=a',
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
    await c.read(sidecarBackfillProvider).run([onServer('a')]);
    expect(server.asked, isEmpty);
  });

  test(
    'a server that cannot be reached ends the run and records nothing',
    () async {
      server.failure = const NetworkException('blip');
      final c = await container();
      await c.read(sidecarBackfillProvider).run([onServer('a'), onServer('b')]);
      expect(server.asked, hasLength(1));
      expect(await c.read(sidecarMissIndexProvider).readAll(), isEmpty);

      // Recovered: asked again by a fresh walker, found this time.
      server.failure = null;
      server.texts['a.ar.vtt'] = vtt;
      c.invalidate(sidecarBackfillProvider);
      await c.read(sidecarBackfillProvider).run([onServer('a')]);
      expect((await c.read(transcriptIndexProvider.future)).length, 1);
    },
  );

  test('the library in error, and local-only clips, are skipped', () async {
    final c = await container(serverError: 'down');
    await c.read(sidecarBackfillProvider).run([onServer('a')]);
    expect(server.asked, isEmpty);

    final ok = await container();
    await ok.read(sidecarBackfillProvider).run([
      LibraryItem.fromOfflineOnly(
        'https://www.youtube.com/watch?v=b',
        '${temp.path}/b.mp4',
      ),
    ]);
    expect(server.asked, isEmpty);
  });

  test('the newest clip is asked first', () async {
    final c = await container();
    await c.read(sidecarBackfillProvider).run([
      onServer('old', at: DateTime.utc(2026, 1)),
      onServer('new', at: DateTime.utc(2026, 9)),
    ]);
    expect(server.asked.first, startsWith('new.'));
  });
}

class _FakeServer implements MeTubeApi {
  final texts = <String, String>{};
  final asked = <String>[];
  MTApiException? failure;

  @override
  Future<String> fetchText(String serverFilename, {int maxBytes = 0}) async {
    asked.add(serverFilename);
    if (failure case final e?) throw e;
    return texts[serverFilename] ?? (throw const NoApiException());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
