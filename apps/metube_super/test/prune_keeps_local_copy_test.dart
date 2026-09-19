import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_actions.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// **Found by reading the code 2026-09-19**, while auditing what deleting
/// on the server touches.
///
/// The library has a documented state for "local and no longer on the
/// server" ([LibraryItem.fromOfflineOnly]) — and deleting from the server
/// made that state unreachable: pruning removed the offline entry along
/// with everything else, so the copy on the phone vanished from the
/// library **while its file stayed on disk**, invisible and unreclaimable.
/// The clip is still playable; its tags, position and cover belong to it.
void main() {
  const onServer = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
  const alsoLocal = 'https://www.youtube.com/watch?v=bbbbbbbbbbb';

  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('mtf_prune'));
  tearDown(() => temp.deleteSync(recursive: true));

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        // Every index write asks for an automatic backup, which wants the
        // diagnostic log and a media folder that only `main` provides.
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// A real file, because the fix checks the disk rather than trusting the
  /// index.
  String saveFile(String name) {
    final file = File('${temp.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(const [0]);
    return file.path;
  }

  Future<void> tagIt(ProviderContainer c, String url) =>
      c.read(tagsIndexProvider).put(url, const ['وثائقي']);

  group('deleting on the server keeps what is on the phone', () {
    test('an item with a local copy keeps its entry and its tags', () async {
      final c = container();
      final path = saveFile('kept.mp4');
      await c.read(offlineIndexProvider).put(alsoLocal, path);
      await tagIt(c, alsoLocal);
      await c
          .read(playbackPositionsProvider)
          .save(alsoLocal, const Duration(minutes: 3));

      await c.read(libraryActionsProvider).pruneItemData([alsoLocal]);

      expect(
        (await c.read(offlineIndexProvider).readAll())[alsoLocal],
        path,
        reason: 'the copy on the phone used to disappear with the server row',
      );
      expect(await c.read(tagsIndexProvider).tagsOf(alsoLocal), ['وثائقي']);
      expect(
        await c.read(playbackPositionsProvider).positionOf(alsoLocal),
        const Duration(minutes: 3),
      );
      expect(File(path).existsSync(), isTrue);
    });

    test('an item with no local copy is still pruned whole', () async {
      final c = container();
      await tagIt(c, onServer);

      await c.read(libraryActionsProvider).pruneItemData([onServer]);

      expect(await c.read(tagsIndexProvider).tagsOf(onServer), isEmpty);
    });

    test(
      'an index entry whose file is gone is a corpse like any other',
      () async {
        final c = container();
        await c
            .read(offlineIndexProvider)
            .put(alsoLocal, '${temp.path}/deleted-from-outside.mp4');
        await tagIt(c, alsoLocal);

        await c.read(libraryActionsProvider).pruneItemData([alsoLocal]);

        expect(await c.read(offlineIndexProvider).readAll(), isEmpty);
        expect(await c.read(tagsIndexProvider).tagsOf(alsoLocal), isEmpty);
      },
    );

    test('deleting the local-only item for good takes its data with '
        'it', () async {
      // The prune above keeps a local copy's tags and position on purpose,
      // so the day the copy itself is deleted they must go with it — or a
      // dead entry stays in every index and playlist (the 2026-09-04
      // defect), now for every clip that was ever deleted on the server.
      final c = container();
      final path = saveFile('local-only.mp4');
      await c.read(offlineIndexProvider).put(alsoLocal, path);
      await tagIt(c, alsoLocal);
      await c
          .read(playbackPositionsProvider)
          .save(alsoLocal, const Duration(minutes: 3));

      await c
          .read(libraryActionsProvider)
          .deleteLocalOnly(
            LibraryItem(
              canonicalUrl: alsoLocal,
              title: 'local only',
              localPath: path,
            ),
          );

      expect(File(path).existsSync(), isFalse);
      expect(await c.read(offlineIndexProvider).readAll(), isEmpty);
      expect(await c.read(tagsIndexProvider).tagsOf(alsoLocal), isEmpty);
      expect(
        await c.read(playbackPositionsProvider).positionOf(alsoLocal),
        isNull,
      );
    });

    test('a mixed batch prunes one and keeps the other', () async {
      final c = container();
      final path = saveFile('kept.mp4');
      await c.read(offlineIndexProvider).put(alsoLocal, path);
      await tagIt(c, alsoLocal);
      await tagIt(c, onServer);

      await c.read(libraryActionsProvider).pruneItemData([onServer, alsoLocal]);

      expect(await c.read(tagsIndexProvider).tagsOf(onServer), isEmpty);
      expect(await c.read(tagsIndexProvider).tagsOf(alsoLocal), ['وثائقي']);
      expect((await c.read(offlineIndexProvider).readAll())[alsoLocal], path);
    });
  });
}
