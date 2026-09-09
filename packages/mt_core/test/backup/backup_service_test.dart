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

  group('BackupService — الصيغة النصّية (قرار المالك 2026-09-04)', () {
    test('roundtrip كامل بكل الأنواع، وبلا أي سرّ', () async {
      await store.setString('server_url', 'https://metube.example.com');
      await store.setBool('library_compact_view', true);
      await store.setInt('player_play_mode', 2);
      await store.setDouble('player_playback_speed', 1.5);
      await store.setStringList('external_urls', ['https://a', 'https://b']);
      await secrets.write(SecretKeys.username, 'user');
      await secrets.write(SecretKeys.password, 'sirri-jiddan');

      final exported = await service.exportToString();
      // نصّ لا ترويسة مشفّرة — ولا مفتاح يموت مع إعادة التثبيت.
      expect(exported, startsWith('{'));
      expect(BackupCrypto.headerOf(exported), isNull);
      expect(exported, isNot(contains('sirri-jiddan')));
      expect(
        exported,
        isNot(contains('user')),
        reason: 'اسم المستخدم لم يعد يُنسخ — الملف بلا سرّ إطلاقاً',
      );

      // جهاز جديد: **بلا استيراد أي مفتاح**، وهذا هو المكسب كله.
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

    test('الاعتمادات المضمّنة في الرابط تُحذف (إصلاح خ-2 باقٍ)', () async {
      await store.setString('server_url', 'https://u:pw@host/path');
      final exported = await service.exportToString();
      expect(exported, isNot(contains('pw@host')));
      expect(exported, contains('https://host/path'));
    });

    test('نصّ ليس نسخة ⇒ BackupFormatException لا انهيار', () async {
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
    });
  });

  /// **الهجرة تبقى**: من كان عنده ملف `MTF1` من إصدار سابق يفتحه بعد
  /// استيراد مفتاحه — الكتابة وحدها هي التي تغيّرت.
  group('استيراد MTF1 المشفَّر (قراءة فقط بعد 2026-09-04)', () {
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

    test('يُقرأ بالمفتاح الصحيح ويعيد اسم المستخدم', () async {
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

    test('مفتاح آخر ⇒ BackupKeyMismatchException', () async {
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

      // استيراد مفتاح Lite القديم (MTKEY1) ثم الملف
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

      // القوائم القديمة تُقرأ عبر PlaylistsStore بصيغة legacy
      final playlists = PlaylistsStore(store: store, mutex: PrefsMutex());
      final imported = await playlists.readAll();
      expect(imported.single.items.single.isLegacy, isTrue);
    });

    /// شكل مصطاد على **نسخة Lite الحقيقية للمالك** (2026-09-01): 32
    /// موضعاً بالثواني نصاً كانت تُستورد ميتة لأن هجرة الأشكال كانت
    /// تعمل على مسار `MTSBACKUP1` وحده.
    test(
      'مواضع Lite القديمة تُهاجَر لمفاتيح §5.1 والوضع الرقمي يُزال',
      () async {
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
      },
    );

    test('جودة قديمة غير صالحة تُجبر على best', () async {
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

  group('استيراد MTSBACKUP1 (Super القديم — قراءة فقط)', () {
    test('حمولة prefs المصنفة تُطبق كما هي', () async {
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

    /// أشكال مصطادة على **نسخة المالك الحقيقية** (2026-09-01) — كلها
    /// كانت تُستورد بصمت ناقصة قبل الإصلاح.
    group('هجرة الأشكال القديمة', () {
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

      test('قائمة بمصفوفة `entries` تُستورد بعناصرها لا فارغة', () async {
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

      test('مواضع الاستئناف تتحول من خريطة ثوانٍ إلى مفاتيح §5.1', () async {
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
        expect(await store.getInt('playback_pos_https://youtu.be/abc'), 30000);
        expect(await store.getInt('playback_pos_https://youtu.be/def'), 125000);
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
      });

      test('قيمة كبيرة تُقرأ ميلي لا ثوانٍ', () async {
        await importLegacySuper({
          'video_playback_positions': {
            't': 's',
            'v': json.encode({'https://youtu.be/ms': '900000'}),
          },
        });
        expect(await store.getInt('playback_pos_https://youtu.be/ms'), 900000);
      });

      test('وضع التشغيل الرقمي القديم يُزال ليعود للافتراضي', () async {
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
      });

      test('نسخة v2 لا تمر بالهجرة (أشكالها حديثة أصلاً)', () async {
        await store.setString('video_playback_positions', '{"u":"30"}');
        await service.importFromString(await service.exportToString());
        expect(await store.getString('video_playback_positions'), '{"u":"30"}');
        expect(await store.get('playback_pos_u'), isNull);
      });
    });
  });

  test('ملف بلا ترويسة ⇒ BackupFormatException', () {
    expect(
      service.importFromString('{"app": "x"}'),
      throwsA(isA<BackupFormatException>()),
    );
  });

  /// **مفهوم المفتاح أُزيل من المنتج** (قرار المالك 2026-09-04): لا
  /// تصدير ولا استيراد. وبلا مفتاح محفوظ لا تُفكّ نسخة مشفّرة قديمة —
  /// وهذا يُقال صراحةً بـ[BackupKeyMismatchException] لا بمفتاح جديد
  /// يُولَّد عبثاً ثم يفشل الفكّ برسالة أبعد عن السبب.
  test('نسخة مشفّرة بلا مفتاح محفوظ ⇒ BackupKeyMismatchException', () async {
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
  });
}
