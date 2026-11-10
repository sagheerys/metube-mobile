import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/downloads_data.dart';
import 'package:metube_desktop/data/folders_data.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/data/local_copies.dart';
import 'package:metube_desktop/di.dart';
import 'package:metube_desktop/platform/startup.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'support/fake_api.dart';

/// Windows' folders inside a test folder, and a dialog that answers
/// [picked].
class _Folders extends NoFolders {
  _Folders(this.root);

  final Directory root;
  String? picked;
  int asked = 0;

  @override
  Future<String?> videos() async => '${root.path}\\Videos';

  @override
  Future<String?> downloads() async => '${root.path}\\Downloads';

  @override
  Future<String?> pick({String? initial}) async {
    asked++;
    return picked;
  }

  @override
  Future<String?> openText({required List<String> extensions}) async => null;

  @override
  Future<void> reveal(String path) async {}

  @override
  Future<void> open(String path) async {}
}

void main() {
  late Directory root;
  late FakeApi api;
  late _Folders folders;
  late MemoryKeyValueStore store;

  ProviderContainer make() {
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWith((ref) => api),
        desktopFoldersProvider.overrideWithValue(folders),
        transferProvider.overrideWithValue(
          (api) => Transfer(api: api, retries: 1, backoff: const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settled(ProviderContainer c) async {
    final clock = Stopwatch()..start();
    while (c.read(localCopiesProvider).any((copy) => copy.isActive)) {
      if (clock.elapsed > const Duration(seconds: 5)) fail('copies hang');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  CopySource clip(String path) => (
    canonicalUrl: 'https://www.instagram.com/reel/$path/',
    title: 'A reel',
    serverPath: path,
    thumbnail: null,
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('ember_copies_');
    api = FakeApi(ServerConfig(baseUrl: 'http://nas:8081'));
    folders = _Folders(root);
    store = MemoryKeyValueStore();
  });
  tearDown(() => root.deleteSync(recursive: true));

  group('**the guard**: nothing here deletes from the server', () {
    test('the engine is built with keepOnServer, and no code in lib can '
        'ask for autoDelete', () {
      final container = make();
      expect(
        container.read(downloadEngineProvider)!.policy,
        DeletePolicy.keepOnServer,
      );
      final offenders = [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File &&
              f.path.endsWith('.dart') &&
              f.readAsStringSync().contains('DeletePolicy.autoDelete'))
            f.path,
      ];
      expect(offenders, isEmpty);
    });

    test(
      'an offline copy, then removing it, leaves the server alone',
      () async {
        api.files['clip.mp4'] = [1, 2, 3];
        final c = make();
        expect(
          await c
              .read(localCopiesProvider.notifier)
              .makeOffline(clip('clip.mp4')),
          isTrue,
        );
        await settled(c);
        final copy = c.read(localCopiesProvider).single;
        expect(copy.phase, CopyPhase.done);
        expect(
          copy.path,
          '${root.path}\\Videos\\MeTube Ember\\Offline\\clip.mp4',
        );
        expect(File(copy.path!).readAsBytesSync(), [1, 2, 3]);
        final index = c.read(offlineIndexProvider);
        expect(
          await index.localPathOf(clip('clip.mp4').canonicalUrl),
          copy.path,
        );

        await c
            .read(localCopiesProvider.notifier)
            .removeLocalCopy(
              LibraryItem(
                canonicalUrl: clip('clip.mp4').canonicalUrl,
                title: 'A reel',
                onServer: true,
                localPath: copy.path,
              ),
            );
        expect(File(copy.path!).existsSync(), isFalse);
        expect(await index.localPathOf(clip('clip.mp4').canonicalUrl), isNull);
        expect(api.deleted, isEmpty);
      },
    );
  });

  group('download to a folder', () {
    test('into the same folder it has on the server, and a second copy '
        'is numbered as Explorer numbers it', () async {
      api.files['Kids/clip.mp4'] = [7];
      final c = make();
      final copies = c.read(localCopiesProvider.notifier);
      await copies.download(clip('Kids/clip.mp4'));
      await copies.download(clip('Kids/clip.mp4'));
      await settled(c);
      final base = '${root.path}\\Downloads\\MeTube Ember\\Kids';
      expect(c.read(localCopiesProvider).map((c) => c.path), [
        '$base\\clip.mp4',
        '$base\\clip (2).mp4',
      ]);
      expect(api.deleted, isEmpty);
      // The file is the user's: not indexed, so the library never shows it.
      expect(await c.read(offlineIndexProvider).readAll(), isEmpty);
    });

    test('"ask me every time" asks, saves where picked, and a closed dialog '
        'downloads nothing', () async {
      api.files['Kids/clip.mp4'] = [7];
      final c = make();
      await c.read(folderSettingsProvider.notifier).setAskEachTime(true);
      final copies = c.read(localCopiesProvider.notifier);
      expect(await copies.download(clip('Kids/clip.mp4')), isFalse);
      expect(c.read(localCopiesProvider), isEmpty);

      folders.picked = '${root.path}\\Elsewhere';
      expect(await copies.download(clip('Kids/clip.mp4')), isTrue);
      await settled(c);
      expect(
        c.read(localCopiesProvider).single.path,
        '${root.path}\\Elsewhere\\clip.mp4',
      );
      expect(folders.asked, 2);
    });

    test('a failed pull keeps its reason and can be tried again', () async {
      final c = make();
      final copies = c.read(localCopiesProvider.notifier);
      await copies.download(clip('gone.mp4'));
      await settled(c);
      final failed = c.read(localCopiesProvider).single;
      expect(failed.phase, CopyPhase.failed);
      expect(failed.error, isA<NetworkException>());

      api.files['gone.mp4'] = [1];
      copies.retry(failed.id);
      await settled(c);
      expect(c.read(localCopiesProvider).single.phase, CopyPhase.done);
    });

    test('the folders are saved on this computer and read back', () async {
      final first = make();
      final settings = first.read(folderSettingsProvider.notifier);
      await settings.setOffline(r'D:\Offline');
      await settings.setServerFolders(false);
      final again = make();
      again.read(folderSettingsProvider);
      await Future<void>.delayed(Duration.zero);
      final read = again.read(folderSettingsProvider);
      expect(read.offline, r'D:\Offline');
      expect(read.serverFolders, isFalse);
      expect(await again.read(offlineFolderProvider.future), r'D:\Offline');
    });
  });

  group('"then download it to this computer"', () {
    DownloadTask finished(String id) =>
        DownloadTask(
          inputUrl: 'https://www.instagram.com/reel/$id/',
          quality: Quality.best,
        ).copyWith(
          canonicalUrl: 'https://www.instagram.com/reel/$id/',
          serverFilename: '$id.mp4',
          title: id,
          phase: TaskPhase.completed,
        );

    test('a task asked for is copied once the server has it', () async {
      api.files['a.mp4'] = [1];
      final c = make();
      final task = finished('a');
      final pulls = {task.id: null as String?};
      pullAfterFinished(
        pulls: pulls,
        copies: c.read(localCopiesProvider.notifier),
        task: task,
      );
      await Future<void>.delayed(Duration.zero);
      await settled(c);
      expect(c.read(localCopiesProvider).single.kind, CopyKind.download);
      expect(pulls, isEmpty);
    });

    test('a task not asked for stays on the server alone', () async {
      final c = make();
      pullAfterFinished(
        pulls: {},
        copies: c.read(localCopiesProvider.notifier),
        task: finished('b'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.read(localCopiesProvider), isEmpty);
    });
  });

  test('names Windows refuses are made safe', () {
    expect(windowsSafeName('a:b?c*.mp4'), 'a_b_c_.mp4');
    expect(windowsSafeName('trailing. '), 'trailing');
    expect(windowsSafeName('...'), '_');
  });

  test('**the guard**: a device name or an endless name from the server '
      'still makes a copy', () {
    // Security review 2026-11-05: `CON.mp4` is a device to Windows, not a
    // file, and a name past 255 characters is refused outright.
    expect(windowsSafeName('CON.mp4'), '_CON.mp4');
    expect(windowsSafeName('nul'), '_nul');
    expect(windowsSafeName('com1.part.mp4'), '_com1.part.mp4');
    expect(windowsSafeName('Console.mp4'), 'Console.mp4');
    final long = windowsSafeName('${'a' * 400}.mp4');
    expect(long.length, maxNameLength);
    expect(long, endsWith('.mp4'));
  });

  test('the start-up list names the program in quotes', () {
    expect(
      WindowsStartup.program(r'C:\Programs\MeTube Ember\metube_desktop.exe'),
      r'"C:\Programs\MeTube Ember\metube_desktop.exe"',
    );
  });
}
