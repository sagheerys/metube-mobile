import 'dart:convert';
import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// أعطال التخزين 2026-09-02: خ-1 (مخزن يتكسر نهائياً)، خ-2 (استعادة
/// غير معاملاتية + تسريب كلمة سر)، خ-3 (تصادم أسماء + جزئيات يتيمة).
void main() {
  group('خ-1 — مخزن القوائم لا ينكسر نهائياً على JSON مشوّه', () {
    test('عنصر بـ items خريطة بدل قائمة يُسقَط ولا يُسقط الباقي', () async {
      final store = MemoryKeyValueStore();
      await store.setString(
        PlaylistsStore.prefsKey,
        json.encode([
          {'id': 'a', 'name': 'سليمة', 'items': []},
          {'id': 'b', 'name': 'تالفة', 'items': {'x': 1}},
          {'id': 'c', 'name': 'سليمة ٢', 'items': []},
        ]),
      );
      final playlists = PlaylistsStore(store: store, mutex: PrefsMutex());

      final all = await playlists.readAll();
      expect(all.map((p) => p.name), ['سليمة', 'سليمة ٢'],
          reason: 'قبل الإصلاح كان TypeError يُفشل readAll كلها للأبد');

      // والكتابة تعمل بعدها (المخزن كان يشلّ نهائياً بلا شفاء ذاتي).
      await playlists.create('جديدة');
      expect((await playlists.readAll()).length, 3);
    });

    test('JSON غير صالح أصلاً ⇒ قائمة فارغة لا رمي', () async {
      final store = MemoryKeyValueStore();
      await store.setString(PlaylistsStore.prefsKey, '{ليس JSON');
      final playlists = PlaylistsStore(store: store, mutex: PrefsMutex());
      expect(await playlists.readAll(), isEmpty);
    });
  });

  group('خ-2 — النسخ الاحتياطي', () {
    test('كلمة السر المضمّنة في الرابط لا تدخل النسخة', () async {
      final store = MemoryKeyValueStore();
      await store.setString('server_url', 'https://user:s3cret@mtube.example');
      await store.setStringList(
          'external_urls', ['https://u:p@a.example', 'https://b.example']);
      final service = BackupService(
        store: store,
        secrets: MemorySecretStore(),
        mutex: PrefsMutex(),
        variant: 'lite',
      );

      final exported = await service.exportToString();
      expect(exported, isNot(contains('s3cret')));
      expect(exported, isNot(contains('user:')));

      // ويبقى الرابط نفسه صالحاً بعد التعقيم.
      expect(BackupService.stripUrlCredentials('https://u:p@a.example/x'),
          'https://a.example/x');
      expect(BackupService.stripUrlCredentials('https://a.example'),
          'https://a.example');
    });
  });

  group('خ-3 — الملفات المحلية', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mtf_files_');
    });
    tearDown(() => dir.delete(recursive: true));

    test('الكنس يحذف الجزئيات القديمة ويترك الجارية والوسائط', () async {
      final old = File('${dir.path}/قديم.mp4.part')..writeAsStringSync('x');
      final fresh = File('${dir.path}/جارٍ.mp4.part')..writeAsStringSync('y');
      final media = File('${dir.path}/سليم.mp4')..writeAsStringSync('z');
      old.setLastModifiedSync(
          DateTime.now().subtract(const Duration(days: 2)));

      final removed = await sweepPartialFiles(dir.path);

      expect(removed, 1);
      expect(old.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue, reason: 'سحب جارٍ لا يُكنس');
      expect(media.existsSync(), isTrue);
    });

    test('مجلد غير موجود ⇒ صفر بلا رمي', () async {
      expect(await sweepPartialFiles('${dir.path}/لا-وجود-له'), 0);
    });
  });
}
