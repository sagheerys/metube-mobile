import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_actions.dart';
import 'package:metube_super/features/library/media_probe.dart';
import 'package:metube_super/features/library/quality_cache.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

/// **The resolution is read when a download finishes, not when the sheet
/// opens** (field report 2026-09-29): reading the server file's header took long
/// enough to notice, and it was repeated on every launch.
void main() {
  const url = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
  const hd = MediaQuality(width: 1920, height: 1080, videoMime: 'video/avc');

  late MemoryKeyValueStore store;

  setUp(() => store = MemoryKeyValueStore());

  ProviderContainer container() {
    final api = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'https://srv.example.com'),
    );
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
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
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  QualityReader reader(ProviderContainer c, _FakeProbe probe) =>
      QualityReader(c.read(_refProvider), probe: probe);

  DownloadTask finished({String? filename = 'Clip.mp4'}) => DownloadTask(
    inputUrl: url,
    quality: Quality.best,
    canonicalUrl: url,
    serverFilename: filename,
    phase: TaskPhase.completed,
  );

  test(
    'a finished download has its quality stored before anyone asks',
    () async {
      final c = container();
      final probe = _FakeProbe(hd);

      await reader(c, probe).prewarm(finished());

      expect(probe.urls.single, contains('/download/'));
      expect(
        (await c.read(mediaQualityIndexProvider).valueOf(url))?.resolutionLabel,
        '1080p',
      );
    },
  );

  test('a clip already known is not read again', () async {
    final c = container();
    await c.read(mediaQualityIndexProvider).remember(url, hd);
    final probe = _FakeProbe(hd);

    await reader(c, probe).prewarm(finished());

    expect(probe.urls, isEmpty);
  });

  test('an unsafe filename is never turned into a URL', () async {
    final c = container();
    final probe = _FakeProbe(hd);

    await reader(c, probe).prewarm(finished(filename: '../etc/passwd'));

    expect(probe.urls, isEmpty);
    expect(await c.read(mediaQualityIndexProvider).readAll(), isEmpty);
  });

  test('a failed read leaves nothing stored and throws nothing', () async {
    final c = container();
    final probe = _FakeProbe(null, fail: true);

    await reader(c, probe).prewarm(finished());

    expect(await c.read(mediaQualityIndexProvider).readAll(), isEmpty);
  });

  test(
    'deleting the item prunes its stored quality with its other data',
    () async {
      final c = container();
      await c.read(mediaQualityIndexProvider).remember(url, hd);

      await c.read(libraryActionsProvider).pruneItemData([url]);

      expect(await c.read(mediaQualityIndexProvider).readAll(), isEmpty);
    },
  );
}

/// Reaching a `Ref` from inside the container: [QualityReader] takes a
/// `Ref`, not a container.
final _refProvider = Provider<Ref>((ref) => ref);

class _FakeProbe extends MediaProbe {
  _FakeProbe(this.answer, {this.fail = false});

  final MediaQuality? answer;
  final bool fail;
  final urls = <String>[];

  @override
  Future<MediaQuality?> quality({
    String? path,
    String? url,
    Map<String, String> headers = const {},
  }) async {
    if (url != null) urls.add(url);
    if (fail) throw StateError('server down');
    return answer;
  }
}
