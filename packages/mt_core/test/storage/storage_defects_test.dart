import 'dart:convert';
import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// Storage defects from 2026-09-02: خ-1 (a store breaking permanently), خ-2
/// (a non-transactional restore plus a password leak), خ-3 (name collisions
/// and orphaned partials).
void main() {
  group('the playlists store is not broken for good by malformed JSON', () {
    test('an entry whose items is a map rather than a list is dropped, and the rest survive', () async {
      final store = MemoryKeyValueStore();
      await store.setString(
        PlaylistsStore.prefsKey,
        json.encode([
          {'id': 'a', 'name': 'سليمة', 'items': []},
          {
            'id': 'b',
            'name': 'تالفة',
            'items': {'x': 1},
          },
          {'id': 'c', 'name': 'سليمة ٢', 'items': []},
        ]),
      );
      final playlists = PlaylistsStore(store: store, mutex: PrefsMutex());

      final all = await playlists.readAll();
      expect(all.map((p) => p.name), [
        'سليمة',
        'سليمة ٢',
      ], reason: 'قبل الإصلاح كان TypeError يُفشل readAll كلها للأبد');

      // And writing works afterwards; the store used to be paralysed
      // permanently with no self-healing.
      await playlists.create('جديدة');
      expect((await playlists.readAll()).length, 3);
    });

    test('outright invalid JSON gives an empty list, not a throw', () async {
      final store = MemoryKeyValueStore();
      await store.setString(PlaylistsStore.prefsKey, '{ليس JSON');
      final playlists = PlaylistsStore(store: store, mutex: PrefsMutex());
      expect(await playlists.readAll(), isEmpty);
    });
  });

  group('backups', () {
    test('a password embedded in the URL never enters the backup', () async {
      final store = MemoryKeyValueStore();
      await store.setString('server_url', 'https://user:s3cret@mtube.example');
      await store.setStringList('external_urls', [
        'https://u:p@a.example',
        'https://b.example',
      ]);
      final service = BackupService(
        store: store,
        secrets: MemorySecretStore(),
        mutex: PrefsMutex(),
        variant: 'lite',
      );

      final exported = await service.exportToString();
      expect(exported, isNot(contains('s3cret')));
      expect(exported, isNot(contains('user:')));

      // And the URL itself stays valid after sanitising.
      expect(
        BackupService.stripUrlCredentials('https://u:p@a.example/x'),
        'https://a.example/x',
      );
      expect(
        BackupService.stripUrlCredentials('https://a.example'),
        'https://a.example',
      );
    });
  });

  group('the local files', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mtf_files_');
    });
    tearDown(() => dir.delete(recursive: true));

    test('the sweep deletes the old partials and leaves the running ones and the media', () async {
      final old = File('${dir.path}/قديم.mp4.part')..writeAsStringSync('x');
      final fresh = File('${dir.path}/جارٍ.mp4.part')..writeAsStringSync('y');
      final media = File('${dir.path}/سليم.mp4')..writeAsStringSync('z');
      old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));

      final removed = await sweepPartialFiles(dir.path);

      expect(removed, 1);
      expect(old.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue, reason: 'سحب جارٍ لا يُكنس');
      expect(media.existsSync(), isTrue);
    });

    test('a missing folder gives zero, without throwing', () async {
      expect(await sweepPartialFiles('${dir.path}/لا-وجود-له'), 0);
    });
  });
}
