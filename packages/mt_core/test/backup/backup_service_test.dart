import 'dart:convert';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  late MemoryKeyValueStore store;
  late MemorySecretStore secrets;
  late BackupService service;

  setUp(() {
    store = MemoryKeyValueStore();
    secrets = MemorySecretStore();
    service = BackupService(
      store: store,
      secrets: secrets,
      mutex: PrefsMutex(),
      variant: 'super',
    );
  });

  group('BackupService: the plain format', () {
    test('a full round trip with every type, and no secret', () async {
      await store.setString('server_url', 'https://metube.example.com');
      await store.setBool('library_compact_view', true);
      await store.setInt('player_play_mode', 2);
      await store.setDouble('player_playback_speed', 1.5);
      await store.setStringList('external_urls', ['https://a', 'https://b']);
      await secrets.write(SecretKeys.username, 'user');
      await secrets.write(SecretKeys.password, 'sirri-jiddan');

      final exported = await service.exportToString();
      // Plain text, no encrypted header, and no key that dies with a
      // reinstall.
      expect(exported, startsWith('{'));
      expect(BackupCrypto.headerOf(exported), isNull);
      expect(exported, isNot(contains('sirri-jiddan')));
      expect(
        exported,
        isNot(contains('user')),
        reason: 'اسم المستخدم لم يعد يُنسخ — الملف بلا سرّ إطلاقاً',
      );

      // A new device: **with no key imported at all**, which is the whole
      // gain.
      final freshStore = MemoryKeyValueStore();
      final freshService = BackupService(
        store: freshStore,
        secrets: MemorySecretStore(),
        mutex: PrefsMutex(),
        variant: 'super',
      );

      final result = await freshService.importFromString(exported);
      expect(result.format, BackupFormat.plain);
      expect(result.keysRestored, 5);
      expect(
        await freshStore.getString('server_url'),
        'https://metube.example.com',
      );
      expect(await freshStore.getBool('library_compact_view'), isTrue);
      expect(await freshStore.getInt('player_play_mode'), 2);
      expect(await freshStore.getDouble('player_playback_speed'), 1.5);
      expect(await freshStore.getStringList('external_urls'), [
        'https://a',
        'https://b',
      ]);
    });

    test('what this phone owes the server stays on this phone', () async {
      // A pending download restored on another phone would have **that**
      // phone pull the file and delete it from the server while this one
      // is still pulling it; the trashcan flag is a fact about one
      // container, not about the user.
      await store.setString(PendingDownloadsStore.prefsKey, '[{"id":"t1"}]');
      await store.setBool(TrashcanProbe.prefsKey, true);
      await store.setBool('library_compact_view', true);

      final exported = await service.exportToString();
      expect(exported, isNot(contains(PendingDownloadsStore.prefsKey)));
      expect(exported, isNot(contains(TrashcanProbe.prefsKey)));

      // And a file that carries them anyway — edited by hand, or from a
      // build between two releases — does not plant them here.
      final planted = json.decode(exported) as Map<String, dynamic>;
      (planted['prefs'] as Map<String, dynamic>)[TrashcanProbe.prefsKey] = {
        't': 'b',
        'v': true,
      };
      final fresh = MemoryKeyValueStore();
      await BackupService(
        store: fresh,
        secrets: MemorySecretStore(),
        mutex: PrefsMutex(),
        variant: 'lite',
      ).importFromString(json.encode(planted));
      expect(await fresh.getBool(TrashcanProbe.prefsKey), isNull);
      expect(await fresh.getBool('library_compact_view'), isTrue);
    });

    test('**the guard**: the covers kept as files stay on this phone, or a '
        'restore elsewhere shows those clips with no cover at all', () async {
      // Found while restoring a backup on a fresh install (2026-11-05):
      // the paths pointed at files of the old install, and the clips they
      // stood for showed blank.
      await store.setString(
        KeptCoverIndex.keptKey,
        '{"https://youtu.be/a":"/data/user/0/app/files/kept_covers/a.jpg"}',
      );
      await store.setBool('library_compact_view', true);

      final exported = await service.exportToString();
      expect(exported, isNot(contains(KeptCoverIndex.keptKey)));

      final planted = json.decode(exported) as Map<String, dynamic>;
      (planted['prefs'] as Map<String, dynamic>)[KeptCoverIndex.keptKey] = {
        't': 's',
        'v': '{"https://youtu.be/a":"/old/kept_covers/a.jpg"}',
      };
      final fresh = MemoryKeyValueStore();
      await BackupService(
        store: fresh,
        secrets: MemorySecretStore(),
        mutex: PrefsMutex(),
        variant: 'super',
      ).importFromString(json.encode(planted));
      expect(await fresh.getString(KeptCoverIndex.keptKey), isNull);
      expect(await fresh.getBool('library_compact_view'), isTrue);
    });

    test('the "what is new" record stays with the installed app', () async {
      // Restored from an older backup it would show a sheet already read,
      // or show one on a fresh install.
      await store.setString(UpdatePrefs.lastSeenVersionKey, '2.3.0');
      await store.setString(UpdatePrefs.notesKey, '{"version":"2.3.0"}');
      final exported = await service.exportToString();
      expect(exported, isNot(contains(UpdatePrefs.lastSeenVersionKey)));
      expect(exported, isNot(contains(UpdatePrefs.notesKey)));

      final planted = json.decode(exported) as Map<String, dynamic>;
      (planted['prefs']
          as Map<String, dynamic>)[UpdatePrefs.lastSeenVersionKey] = {
        't': 's',
        'v': '2.2.0',
      };
      final fresh = MemoryKeyValueStore();
      await BackupService(
        store: fresh,
        secrets: MemorySecretStore(),
        mutex: PrefsMutex(),
        variant: 'lite',
      ).importFromString(json.encode(planted));
      expect(await fresh.getString(UpdatePrefs.lastSeenVersionKey), isNull);
    });

    test('credentials embedded in the URL are stripped', () async {
      await store.setString('server_url', 'https://u:pw@host/path');
      final exported = await service.exportToString();
      expect(exported, isNot(contains('pw@host')));
      expect(exported, contains('https://host/path'));
    });

    test(
      'text that is not a backup raises BackupFormatException, not a crash',
      () async {
        expect(
          service.importFromString('مرحبا'),
          throwsA(isA<BackupFormatException>()),
        );
        expect(
          service.importFromString('{"app":"شيء آخر"}'),
          throwsA(isA<BackupFormatException>()),
        );
        expect(
          service.importFromString('{ليس json'),
          throwsA(isA<BackupFormatException>()),
        );
      },
    );
  });

  /// **Migration still works**: anyone holding an `MTF1` file from an
  /// earlier release opens it after importing its key. Only writing
  /// changed.
  group('importing the encrypted MTF1, read only', () {
    String legacyV2File(String keyBase64, Map<String, dynamic> prefs) =>
        BackupCrypto.encrypt(
          plaintext: json.encode({
            'app': 'MTF',
            'variant': 'super',
            'version': 2,
            'prefs': prefs,
            'secure': {'username': 'user'},
          }),
          keyBase64: keyBase64,
        );

    test('it reads with the right key and returns the username', () async {
      final key = BackupCrypto.generateKeyBase64();
      await secrets.write(SecretKeys.backupAesKey, key);
      final file = legacyV2File(key, {
        'server_url': {'t': 's', 'v': 'https://old.example'},
      });

      final result = await service.importFromString(file);
      expect(result.format, BackupFormat.v2);
      expect(await store.getString('server_url'), 'https://old.example');
      expect(await secrets.read(SecretKeys.username), 'user');
    });

    test('another key raises BackupKeyMismatchException', () async {
      final file = legacyV2File(BackupCrypto.generateKeyBase64(), const {});
      final other = BackupService(
        store: MemoryKeyValueStore(),
        secrets: MemorySecretStore(),
        mutex: PrefsMutex(),
        variant: 'lite',
      );
      expect(
        other.importFromString(file),
        throwsA(isA<BackupKeyMismatchException>()),
      );
    });
  });

  group('importing MTBACKUP1, old Lite, read only', () {
    test('the real format, byte for byte, migrates to the old keys', () async {
      // Builds the file with exactly the old BackupHelper layout.
      final legacyKey = BackupCrypto.generateKeyBase64();
      final legacyPayload = json.encode({
        'app': 'MeTube Lite',
        'version': '2.0.0',
        'backupDate': '2025-12-01T10:00:00.000',
        'settings': {
          'serverUrl': 'https://old.example.com',
          'videoQuality': '720',
          'themeMode': 'dark',
          'locale': 'ar',
          'playMode': 1,
          'username': 'family-user',
        },
        'videoMetadata': {
          'https://youtu.be/dQw4w9WgXcQ': {'title': 'قديم'},
        },
        'playbackPositions': {'https://youtu.be/dQw4w9WgXcQ': '42'},
        'savedPlaylists': [
          {
            'name': 'قديمة',
            'createdAt': '2025-01-01T00:00:00',
            'videoPaths': ['/storage/emulated/0/Download/MeTube_Lite/a.mp4'],
          },
        ],
        'stats': {'totalVideos': 1},
      });
      final legacyFile = BackupCrypto.encrypt(
        plaintext: legacyPayload,
        keyBase64: legacyKey,
        header: BackupCrypto.headerLegacyLite,
      );

      // Import the old Lite key (MTKEY1), then the file.
      await secrets.write(SecretKeys.backupAesKey, legacyKey);
      final result = await service.importFromString(legacyFile);

      expect(result.format, BackupFormat.legacyLite);
      expect(await store.getString('server_url'), 'https://old.example.com');
      expect(await store.getString('video_quality'), '720');
      expect(await store.getString('theme_mode'), 'dark');
      expect(await store.getString('app_locale'), 'ar');
      expect(
        await store.get('player_play_mode'),
        isNull,
        reason: 'الوضع الرقمي القديم يُزال في هجرة الأشكال',
      );
      expect(
        await store.getInt('playback_pos_https://youtu.be/dQw4w9WgXcQ'),
        42000,
      );
      expect(await secrets.read(SecretKeys.username), 'family-user');

      // Old playlists are read through PlaylistsStore in the legacy format.
      final playlists = PlaylistsStore(store: store, mutex: PrefsMutex());
      final imported = await playlists.readAll();
      expect(imported.single.items.single.isLegacy, isTrue);
    });

    /// A shape caught on **a real Lite backup** (2026-09-01): 32 positions
    /// stored as seconds in strings were imported dead, because the shape
    /// migration only ran on the `MTSBACKUP1` path.
    test('old Lite positions migrate to the current keys, and the numeric mode is dropped', () async {
      final key = BackupCrypto.generateKeyBase64();
      await secrets.write(SecretKeys.backupAesKey, key);
      await service.importFromString(
        BackupCrypto.encrypt(
          plaintext: json.encode({
            'app': 'MeTube Lite',
            'settings': {'playMode': 1},
            'playbackPositions': {
              'https://youtu.be/abc': '12',
              'https://youtu.be/def': 305,
            },
          }),
          keyBase64: key,
          header: BackupCrypto.headerLegacyLite,
        ),
      );
      expect(await store.getInt('playback_pos_https://youtu.be/abc'), 12000);
      expect(await store.getInt('playback_pos_https://youtu.be/def'), 305000);
      expect(await store.getString('video_playback_positions'), isNull);
      expect(
        await store.get('player_play_mode'),
        isNull,
        reason: 'الرقم القديم يُزال ليعود الوضع للافتراضي',
      );
    });

    test('an invalid legacy quality is forced to best', () async {
      final key = BackupCrypto.generateKeyBase64();
      await secrets.write(SecretKeys.backupAesKey, key);
      final file = BackupCrypto.encrypt(
        plaintext: json.encode({
          'app': 'MeTube Lite',
          'settings': {'videoQuality': '4k'},
        }),
        keyBase64: key,
        header: BackupCrypto.headerLegacyLite,
      );
      await service.importFromString(file);
      expect(await store.getString('video_quality'), 'best');
    });
  });

  group('importing MTSBACKUP1, old Super, read only', () {
    test('a typed prefs payload is applied as it is', () async {
      final key = BackupCrypto.generateKeyBase64();
      await secrets.write(SecretKeys.backupAesKey, key);
      final file = BackupCrypto.encrypt(
        plaintext: json.encode({
          'app': 'MeTube Super',
          'version': '1.0.0',
          'prefs': {
            'server_url': {'t': 's', 'v': 'https://truenas.local:8081'},
            'auto_switch_enabled': {'t': 'b', 'v': true},
            'tags_index': {
              't': 's',
              'v': '{"https://youtu.be/dQw4w9WgXcQ":["أناشيد"]}',
            },
          },
          'secure': {'username': 'user'},
        }),
        keyBase64: key,
        header: BackupCrypto.headerLegacySuper,
      );
      final result = await service.importFromString(file);
      expect(result.format, BackupFormat.legacySuper);
      expect(result.keysRestored, 3);
      expect(await store.getString('server_url'), 'https://truenas.local:8081');
      expect(await store.getBool('auto_switch_enabled'), isTrue);
      expect(await secrets.read(SecretKeys.username), 'user');

      final tags = TagsIndex(store: store, mutex: PrefsMutex());
      expect(await tags.tagsOf('https://youtu.be/dQw4w9WgXcQ'), ['أناشيد']);
    });

    /// Shapes caught on **a real backup** (2026-09-01), all of which
    /// imported silently incomplete before the fix.
    group('migrating the legacy shapes', () {
      Future<void> importLegacySuper(Map<String, dynamic> prefs) async {
        final key = BackupCrypto.generateKeyBase64();
        await secrets.write(SecretKeys.backupAesKey, key);
        await service.importFromString(
          BackupCrypto.encrypt(
            plaintext: json.encode({'app': 'MeTube Super', 'prefs': prefs}),
            keyBase64: key,
            header: BackupCrypto.headerLegacySuper,
          ),
        );
      }

      test('a playlist with an `entries` array is imported with its items, not empty', () async {
        await importLegacySuper({
          'saved_playlists': {
            't': 's',
            'v': json.encode([
              {
                'name': 'Music',
                'createdAt': '2025-05-01T10:00:00.000',
                'entries': [
                  {
                    'canonicalUrl': 'https://youtu.be/abc',
                    'serverFilename': 'a.mp3',
                    'cachedTitle': 'أول',
                    'cachedThumb': 'https://img/1.jpg',
                  },
                  {'canonicalUrl': 'https://youtu.be/def'},
                ],
              },
            ]),
          },
        });
        final playlists = await PlaylistsStore(
          store: store,
          mutex: PrefsMutex(),
        ).readAll();
        expect(playlists.single.name, 'Music');
        expect(playlists.single.items.length, 2);
        expect(playlists.single.items.first.cachedTitle, 'أول');
        expect(playlists.single.items.first.serverFilename, 'a.mp3');
      });

      test(
        'resume positions turn from a map of seconds into the current keys',
        () async {
          await importLegacySuper({
            'video_playback_positions': {
              't': 's',
              'v': json.encode({
                'https://youtu.be/abc': '30',
                'https://youtu.be/def': '125',
                'https://youtu.be/zero': '0',
              }),
            },
          });
          expect(
            await store.getInt('playback_pos_https://youtu.be/abc'),
            30000,
          );
          expect(
            await store.getInt('playback_pos_https://youtu.be/def'),
            125000,
          );
          expect(
            await store.get('playback_pos_https://youtu.be/zero'),
            isNull,
            reason: 'الصفر لا يستحق مفتاحاً',
          );
          expect(
            await store.getString('video_playback_positions'),
            isNull,
            reason: 'المفتاح القديم يُزال فلا يتكرر في كل تصدير لاحق',
          );
        },
      );

      test('a large value is read as milliseconds, not seconds', () async {
        await importLegacySuper({
          'video_playback_positions': {
            't': 's',
            'v': json.encode({'https://youtu.be/ms': '900000'}),
          },
        });
        expect(await store.getInt('playback_pos_https://youtu.be/ms'), 900000);
      });

      test(
        'the old numeric play mode is dropped, back to the default',
        () async {
          await importLegacySuper({
            'player_play_mode': {'t': 'i', 'v': 0},
            'player_play_mode_Music': {'t': 'i', 'v': 2},
            'video_quality': {'t': 's', 'v': 'audio'},
          });
          expect(await store.get('player_play_mode'), isNull);
          expect(await store.get('player_play_mode_Music'), isNull);
          expect(
            await store.getString('video_quality'),
            'audio',
            reason: 'بقية المفاتيح لا تُمس',
          );
        },
      );

      test(
        'a v2 backup skips the migration: its shapes are already current',
        () async {
          await store.setString('video_playback_positions', '{"u":"30"}');
          await service.importFromString(await service.exportToString());
          expect(
            await store.getString('video_playback_positions'),
            '{"u":"30"}',
          );
          expect(await store.get('playback_pos_u'), isNull);
        },
      );
    });
  });

  test('a file with no header raises BackupFormatException', () {
    expect(
      service.importFromString('{"app": "x"}'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  /// **The key concept was removed from the product** (decision
  /// 2026-09-04): no export and no import. With no stored key an old
  /// encrypted backup cannot be decrypted, and that is said plainly with
  /// [BackupKeyMismatchException] rather than by generating a new key for
  /// nothing and then failing with a message further from the cause.
  test(
    'an encrypted backup with no stored key raises BackupKeyMismatchException',
    () async {
      final file = BackupCrypto.encrypt(
        plaintext: json.encode({'app': 'MTF', 'version': 2, 'prefs': {}}),
        keyBase64: BackupCrypto.generateKeyBase64(),
      );
      expect(await secrets.read(SecretKeys.backupAesKey), isNull);
      await expectLater(
        service.importFromString(file),
        throwsA(isA<BackupKeyMismatchException>()),
      );
      expect(
        await secrets.read(SecretKeys.backupAesKey),
        isNull,
        reason: 'ولا يُولَّد مفتاح لا يفكّ شيئاً',
      );
    },
  );

  /// Cloudflare Access: a backup file is
  /// something people send to themselves by e-mail or keep in a cloud drive,
  /// so the service token must not be in it, and restoring a file must not
  /// wipe a token the phone already holds.
  group('a backup that points somewhere new', () {
    // Security review 2026-11-05: the password and the token stay in the
    // secret store through a restore, and went to whatever address the
    // file named. A "backup" from someone else was enough to have them
    // sent to that person's server.
    String plain(Map<String, Object> prefs, {Map<String, Object>? secure}) =>
        json.encode({
          'app': 'MTF',
          'variant': 'super',
          'version': 3,
          'prefs': prefs,
          'secure': ?secure,
        });

    Future<void> seed() async {
      await store.setString('active_url', 'http://192.168.1.20:8081');
      await store.setString('local_url', 'http://192.168.1.20:8081');
      await store.setStringList('external_urls', [
        'https://metube.example.com',
      ]);
      await secrets.write(SecretKeys.username, 'me');
      await secrets.write(SecretKeys.password, 'sirri');
      await secrets.write(SecretKeys.cfAccessClientId, 'id.access');
      await secrets.write(SecretKeys.cfAccessClientSecret, 's3cr3t');
    }

    test('**the guard**: an address this install never knew drops the '
        'password and the token', () async {
      await seed();
      final result = await service.importFromString(
        plain({
          'active_url': {'t': 's', 'v': 'https://evil.example'},
        }),
      );
      expect(await store.getString('active_url'), 'https://evil.example');
      expect(result.signInCleared, isTrue);
      expect(await secrets.read(SecretKeys.password), isNull);
      expect(await secrets.read(SecretKeys.cfAccessClientId), isNull);
      expect(await secrets.read(SecretKeys.cfAccessClientSecret), isNull);
    });

    test("the same in the Windows app's own keys", () async {
      await store.setStringList('ember_server_addresses', [
        'http://192.168.1.20:8081',
      ]);
      await secrets.write(SecretKeys.password, 'sirri');
      await service.importFromString(
        plain({
          'ember_server_addresses': {
            't': 'l',
            'v': ['http://192.168.1.20:8081', 'https://evil.example'],
          },
        }),
      );
      expect(await secrets.read(SecretKeys.password), isNull);
    });

    test("one's own backup, or the other address of the same server, "
        'keeps everything', () async {
      await seed();
      final mine = await service.exportToString();
      expect((await service.importFromString(mine)).signInCleared, isFalse);
      // Taken while on the outside address, restored while at home.
      final result = await service.importFromString(
        plain({
          'active_url': {'t': 's', 'v': 'https://metube.example.com/'},
        }),
      );
      expect(result.signInCleared, isFalse);
      expect(await secrets.read(SecretKeys.password), 'sirri');
      expect(await secrets.read(SecretKeys.cfAccessClientSecret), 's3cr3t');
    });

    test('serverOf names the server a plain backup points at', () async {
      await store.setString('active_url', 'https://u:p@metube.example.com');
      expect(
        BackupService.serverOf(await service.exportToString()),
        'https://metube.example.com',
      );
      expect(BackupService.serverOf('{"app":"MTF","prefs":{}}'), isNull);
      expect(BackupService.serverOf('not json'), isNull);
      expect(BackupService.serverOf('{"app":"other"}'), isNull);
    });

    test('a username written into a plain file is ignored', () async {
      await seed();
      await service.importFromString(
        plain(const {}, secure: {'username': 'someone-else'}),
      );
      expect(await secrets.read(SecretKeys.username), 'me');
    });

    test('credentials inside an address are stripped on the way in', () async {
      await service.importFromString(
        plain({
          'server_url': {'t': 's', 'v': 'https://u:p@metube.example.com'},
          'external_urls': {
            't': 'l',
            'v': ['https://u:p@a.example', 'plain text'],
          },
        }),
      );
      expect(await store.getString('server_url'), 'https://metube.example.com');
      expect(await store.getStringList('external_urls'), [
        'https://a.example',
        'plain text',
      ]);
    });
  });

  group('the Cloudflare Access pair and backups', () {
    const id = '4c1f0d7a.access';
    const secret = '9a7e11c0b2d4f6a8';

    Future<void> seed() async {
      await secrets.write(SecretKeys.cfAccessClientId, id);
      await secrets.write(SecretKeys.cfAccessClientSecret, secret);
      await store.setString('server_url', 'https://metube.example.com');
      await store.setBool('library_compact_view', true);
    }

    Future<void> expectKept() async {
      expect(await secrets.read(SecretKeys.cfAccessClientId), id);
      expect(await secrets.read(SecretKeys.cfAccessClientSecret), secret);
    }

    test('the exported file holds neither value', () async {
      // Defect: a live credential written into a file that gets shared.
      await seed();
      final exported = await service.exportToString();
      expect(exported, isNot(contains(id)));
      expect(exported, isNot(contains(secret)));
      expect(exported, isNot(contains('CF-Access')));
    });

    test('restoring a plain backup leaves the stored pair alone', () async {
      // Defect: a restore on a phone that is already set up clearing the
      // token, so every request fails until the user types it again.
      await seed();
      final exported = await service.exportToString();
      await service.importFromString(exported);
      await expectKept();
    });

    test('restoring each legacy format leaves the stored pair alone', () async {
      await seed();
      final key = BackupCrypto.generateKeyBase64();
      await secrets.write(SecretKeys.backupAesKey, key);

      await service.importFromString(
        BackupCrypto.encrypt(
          plaintext: json.encode({
            'app': 'MTF',
            'variant': 'super',
            'version': 2,
            'prefs': {
              'server_url': {'t': 's', 'v': 'https://old.example'},
            },
            'secure': {'username': 'user'},
          }),
          keyBase64: key,
        ),
      );
      await expectKept();

      await service.importFromString(
        BackupCrypto.encrypt(
          plaintext: json.encode({
            'app': 'MeTube Lite',
            'settings': {'serverUrl': 'https://old.example.com'},
          }),
          keyBase64: key,
          header: BackupCrypto.headerLegacyLite,
        ),
      );
      await expectKept();

      await service.importFromString(
        BackupCrypto.encrypt(
          plaintext: json.encode({
            'app': 'MeTube Super',
            'prefs': {
              'server_url': {'t': 's', 'v': 'https://truenas.local:8081'},
            },
          }),
          keyBase64: key,
          header: BackupCrypto.headerLegacySuper,
        ),
      );
      await expectKept();
    });
  });
}
