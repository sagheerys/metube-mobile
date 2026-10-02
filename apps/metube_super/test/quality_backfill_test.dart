import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/library/media_probe.dart';
import 'package:metube_super/features/library/quality_backfill.dart';
import 'package:metube_super/features/library/quality_cache.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

/// **The library that existed before, and what subscriptions download,
/// get their quality stored too** (field report 2026-09-29): reading ahead on
/// completion only sees downloads added from this app.
void main() {
  const hd = MediaQuality(width: 1920, height: 1080, videoMime: 'video/avc');

  LibraryItem onServer(String id, {Duration? duration = _minute}) =>
      LibraryItem(
        canonicalUrl: 'https://www.youtube.com/watch?v=$id',
        title: id,
        serverFilename: '$id.mp4',
        onServer: true,
        duration: duration,
      );

  late _FakeProbe probe;

  ProviderContainer container({Object? serverError}) {
    probe = _FakeProbe(hd);
    final api = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'https://srv.example.com'),
    );
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
        ),
        playbackResolverProvider.overrideWithValue(
          PlaybackSourceResolver(
            endpoint: ServerStreamEndpoint.fromApi(api),
            fileExists: (_) => false,
          ),
        ),
        libraryServerErrorProvider.overrideWithValue(serverError),
        qualityReaderProvider.overrideWith(
          (ref) => QualityReader(ref, probe: probe),
        ),
        qualityBackfillProvider.overrideWith(
          (ref) => QualityBackfill(ref, pause: Duration.zero),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<Map<String, MediaQuality>> stored(ProviderContainer c) =>
      c.read(mediaQualityIndexProvider).readAll();

  test('every readable item gets its quality stored', () async {
    final c = container();
    await c.read(qualityBackfillProvider).run([onServer('a'), onServer('b')]);

    expect((await stored(c)).keys, hasLength(2));
  });

  test('an item the enricher has not read yet is never handed to the '
      'platform', () async {
    // No duration means nobody has confirmed the file exists. A deleted
    // file's URL made the platform reader retry for 80 seconds.
    final c = container();
    await c.read(qualityBackfillProvider).run([onServer('x', duration: null)]);

    expect(probe.calls, isEmpty);
  });

  test('an item already stored is not read again', () async {
    final c = container();
    final item = onServer('a');
    await c.read(mediaQualityIndexProvider).remember(item.canonicalUrl, hd);

    await c.read(qualityBackfillProvider).run([item]);

    expect(probe.calls, isEmpty);
  });

  test('an item whose probe failed recently is left alone', () async {
    final c = container();
    final item = onServer('a');
    await c
        .read(probeFailureIndexProvider)
        .put(item.canonicalUrl, DateTime.now());

    await c.read(qualityBackfillProvider).run([item]);

    expect(probe.calls, isEmpty);
  });

  test('with the server down only local copies are read', () async {
    final c = container(serverError: StateError('down'));
    const local = LibraryItem(
      canonicalUrl: 'https://www.youtube.com/watch?v=local',
      title: 'local',
      localPath: '/storage/local.mp4',
      duration: _minute,
    );

    await c.read(qualityBackfillProvider).run([onServer('a'), local]);

    expect(probe.calls, ['/storage/local.mp4']);
  });

  test(
    'a file the platform cannot parse is not asked again this run',
    () async {
      final c = container();
      probe.answer = null;
      final backfill = c.read(qualityBackfillProvider);

      await backfill.run([onServer('a')]);
      await backfill.run([onServer('a')]);

      expect(probe.calls, hasLength(1));
    },
  );

  test('a cancelled backfill stops reading', () async {
    final c = container();
    final backfill = c.read(qualityBackfillProvider)..cancel();

    await backfill.run([onServer('a')]);

    expect(probe.calls, isEmpty);
  });
}

const _minute = Duration(minutes: 1);

class _FakeProbe extends MediaProbe {
  _FakeProbe(this.answer);

  MediaQuality? answer;
  final calls = <String>[];

  @override
  Future<MediaQuality?> quality({
    String? path,
    String? url,
    Map<String, String> headers = const {},
  }) async {
    calls.add(path ?? url ?? '');
    return answer;
  }
}
