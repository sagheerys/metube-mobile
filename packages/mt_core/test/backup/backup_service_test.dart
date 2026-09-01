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

  group('BackupService — v2 (MTF1)', () {
    test('roundtrip كامل بكل الأنواع + username', () async {
      await store.setString('server_url', 'https://metube.example.com');
      await store.setBool('library_compact_view', true);
      await store.setInt('player_play_mode', 2);
      await store.setDouble('player_playback_speed', 1.5);
      await store.setStringList('external_urls', ['https://a', 'https://b']);
      await secrets.write(SecretKeys.username, 'yasir');

      final exported = await service.exportToString();
      expect(exported, startsWith('MTF1\n'));

      // استيراد في جهاز جديد بنفس المفتاح (محاكاة استيراد ملف المفتاح)
      final freshStore = MemoryKeyValueStore();
      final freshSecrets = MemorySecretStore();
      await freshSecrets.write(SecretKeys.backupAesKey,
          (await secrets.read(SecretKeys.backupAesKey))!);
      final freshService = BackupService(
        store: freshStore,
        secrets: freshSecrets,
        mutex: PrefsMutex(),
        variant: 'super',
      );

      final result = await freshService.importFromString(exported);
      expect(result.format, BackupFormat.v2);
      expect(result.keysRestored, 5);
      expect(await freshStore.getString('server_url'),
          'https://metube.example.com');
      expect(await freshStore.getBool('library_compact_view'), isTrue);
      expect(await freshStore.getInt('player_play_mode'), 2);
      expect(await freshStore.getDouble('player_playback_speed'), 1.5);
      expect(await freshStore.getStringList('external_urls'),
          ['https://a', 'https://b']);
      expect(await freshSecrets.read(SecretKeys.username), 'yasir');
    });

    test('كلمة المرور لا تدخل النسخة أبداً', () async {
      await secrets.write(SecretKeys.password, 'sirri-jiddan');
      await store.setString('server_url', 'https://s');
      final exported = await service.exportToString();
      final plaintext = BackupCrypto.decrypt(
        contents: exported,
        keyBase64: (await secrets.read(SecretKeys.backupAesKey))!,
      );
      expect(plaintext, isNot(contains('sirri-jiddan')));
      expect(plaintext, isNot(contains('password')));
    });

    test('مفتاح آخر ⇒ BackupKeyMismatchException', () async {
      final exported = await service.exportToString();
      final other = BackupService(
        store: MemoryKeyValueStore(),
        secrets: MemorySecretStore(),
        mutex: PrefsMutex(),
        variant: 'lite',
      );
      expect(other.importFromString(exported),
          throwsA(isA<BackupKeyMismatchException>()));
    });
  });

  group('استيراد MTBACKUP1 (Lite القديم — قراءة فقط)', () {
    test('التنسيق الحقيقي بايتاً ببايت يُهاجَر للمفاتيح القديمة', () async {
      // بناء الملف بنفس تخطيط BackupHelper القديم حرفياً
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
        'playbackPositions': {'https://youtu.be/dQw4w9WgXcQ': 42000},
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

      // استيراد مفتاح Lite القديم (MTKEY1) ثم الملف
      expect(await service.importKeyFile('MTKEY1\n$legacyKey\n'), isTrue);
      final result = await service.importFromString(legacyFile);

      expect(result.format, BackupFormat.legacyLite);
      expect(await store.getString('server_url'), 'https://old.example.com');
      expect(await store.getString('video_quality'), '720');
      expect(await store.getString('theme_mode'), 'dark');
      expect(await store.getString('app_locale'), 'ar');
      expect(await store.getInt('player_play_mode'), 1);
      expect(await secrets.read(SecretKeys.username), 'family-user');

      // القوائم القديمة تُقرأ عبر PlaylistsStore بصيغة legacy
      final playlists =
          PlaylistsStore(store: store, mutex: PrefsMutex());
      final imported = await playlists.readAll();
      expect(imported.single.items.single.isLegacy, isTrue);
    });

    test('جودة قديمة غير صالحة تُجبر على best', () async {
      final key = BackupCrypto.generateKeyBase64();
      await service.importKeyFile('MTKEY1\n$key\n');
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

  group('استيراد MTSBACKUP1 (Super القديم — قراءة فقط)', () {
    test('حمولة prefs المصنفة تُطبق كما هي', () async {
      final key = BackupCrypto.generateKeyBase64();
      await service.importKeyFile('MTSKEY1\n$key\n');
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
          'secure': {'username': 'yasir'},
        }),
        keyBase64: key,
        header: BackupCrypto.headerLegacySuper,
      );
      final result = await service.importFromString(file);
      expect(result.format, BackupFormat.legacySuper);
      expect(result.keysRestored, 3);
      expect(await store.getString('server_url'),
          'https://truenas.local:8081');
      expect(await store.getBool('auto_switch_enabled'), isTrue);
      expect(await secrets.read(SecretKeys.username), 'yasir');

      final tags = TagsIndex(store: store, mutex: PrefsMutex());
      expect(await tags.tagsOf('https://youtu.be/dQw4w9WgXcQ'), ['أناشيد']);
    });
  });

  test('ملف بلا ترويسة ⇒ BackupFormatException', () {
    expect(service.importFromString('{"app": "x"}'),
        throwsA(isA<BackupFormatException>()));
  });

  test('exportKeyFile/importKeyFile roundtrip', () async {
    final keyFile = await service.exportKeyFile();
    expect(keyFile, startsWith('MTFKEY1\n'));
    final other = BackupService(
      store: MemoryKeyValueStore(),
      secrets: MemorySecretStore(),
      mutex: PrefsMutex(),
      variant: 'lite',
    );
    expect(await other.importKeyFile(keyFile), isTrue);
    expect(await other.importKeyFile('garbage'), isFalse);
  });
}
