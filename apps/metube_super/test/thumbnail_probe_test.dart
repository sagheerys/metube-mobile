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

/// **Guards for the thumbnail defect (measured on a real device
/// 2026-09-07).**
///
/// The server library had no thumbnails except YouTube's, which are derived
/// from the id rather than probed. The measured cause: **one record** in
/// `/history` for a file deleted from the server's disk (1 out of 269).
/// Handing its URL to `MediaMetadataRetriever` makes the Android platform
/// retry **ten times on an 8s timeout**, so everything behind it froze for
/// over 80 seconds every session. And the failure was swallowed silently.
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
      '${Directory.systemTemp.path}/mtf_probe_${DateTime.now().microsecondsSinceEpoch}.log',
    );
    logger = MTLogger(filePath: logFile.path);
    clearErrorSignature('probe');
  });

  tearDown(() async {
    try {
      if (await logFile.exists()) await logFile.delete();
    } on FileSystemException {
      // Windows may lock it for a moment during a late write.
    }
  });

  ProviderContainer containerWith(int status, MediaProbe probe) {
    final dio = Dio()..httpClientAdapter = _StatusAdapter(status);
    final api = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'https://srv.example.com'),
      dio: dio,
    );
    return ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          const SuperSettings(activeUrl: 'https://srv.example.com'),
        ),
        loggerProvider.overrideWithValue(logger),
        apiClientProvider.overrideWithValue(api),
        playbackResolverProvider.overrideWithValue(
          PlaybackSourceResolver(
            endpoint: ServerStreamEndpoint.fromApi(api),
            fileExists: (_) => false,
          ),
        ),
      ],
    );
  }

  test('a file missing on the server is never handed to the platform, and the reason is logged', () async {
    final probe = _RecordingProbe();
    final container = containerWith(404, probe);
    addTearDown(container.dispose);

    await LibraryEnricher(
      container.read(_refProvider),
      probe: probe,
    ).enrich(const [item]);

    // **The first guard**: without the pre-check the dead URL went to
    // `MediaMetadataRetriever` and froze the queue for 80 seconds.
    expect(probe.calls, isEmpty, reason: 'رابط ميت لا يُسلَّم للمنصة');

    // **The second guard**: the failure is written down; it used to be
    // swallowed in complete silence.
    expect(await logger.readAll(), contains('file missing on server'));

    // **The third guard**: it is deferred by a day, so it is not retried
    // at every launch.
    final failures = await container.read(probeFailureIndexProvider).readAll();
    expect(failures.containsKey(item.canonicalUrl), isTrue);
  });

  test(
    'an item that failed recently is skipped even if the file came back',
    () async {
      final index = ProbeFailureIndex(store: store, mutex: PrefsMutex());
      await index.put(item.canonicalUrl, DateTime.now());

      final probe = _RecordingProbe();
      final container = containerWith(206, probe); // the server is healthy now
      addTearDown(container.dispose);

      await LibraryEnricher(
        container.read(_refProvider),
        probe: probe,
      ).enrich(const [item]);

      expect(probe.calls, isEmpty, reason: 'التبريد يمنع إعادة المحاولة فوراً');
    },
  );

  test('a file that exists really is probed', () async {
    final probe = _RecordingProbe();
    final container = containerWith(206, probe);
    addTearDown(container.dispose);

    await LibraryEnricher(
      container.read(_refProvider),
      probe: probe,
    ).enrich(const [item]);

    expect(probe.calls, hasLength(1));
    expect(probe.calls.single.single.url, contains('/download/'));
  });

  test('the cooldown expires after a day', () {
    final index = ProbeFailureIndex(store: store, mutex: PrefsMutex());
    final old = DateTime.now().subtract(const Duration(days: 2));
    expect(index.isCoolingDown({'k': old}, 'k'), isFalse);
    expect(index.isCoolingDown({'k': DateTime.now()}, 'k'), isTrue);
  });

  test(
    'a cover that vanished from disk is forgotten and probed again',
    () async {
      final artwork = ArtworkIndex(store: store, mutex: PrefsMutex());
      // A path in a cache folder that was wiped: this is what Android did to
      // the thumbnails.
      await artwork.put(item.canonicalUrl, '/data/cache/thumbs/gone.jpg');

      final probe = _RecordingProbe();
      final container = containerWith(206, probe);
      addTearDown(container.dispose);

      // The item carries a cover in its model, so without the cleanup it is
      // never a candidate for probing.
      const withThumb = LibraryItem(
        canonicalUrl: 'https://instagram.com/reel/abc',
        title: 'Video by someone',
        serverFilename: 'Video by someone.mp4',
        onServer: true,
        thumbnail: '/data/cache/thumbs/gone.jpg',
        duration: Duration(seconds: 30),
        aspectRatio: 0.5625,
      );
      await LibraryEnricher(
        container.read(_refProvider),
        probe: probe,
      ).enrich(const [withThumb]);

      expect(probe.calls, hasLength(1), reason: 'يُعاد سبره في نفس الجولة');
      // The dead path is gone, replaced by what the new probe produced.
      expect(
        (await artwork.readAll())[item.canonicalUrl],
        isNot('/data/cache/thumbs/gone.jpg'),
      );
    },
  );
}

/// Reaching a `Ref` from inside the container: `LibraryEnricher` takes a
/// `Ref`, not a container.
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
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      utf8.encode(status == 404 ? 'no' : 'x'),
      status,
      headers: {
        't': ['application/octet-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
