import 'dart:convert';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  late MemoryKeyValueStore store;
  late PlaylistsStore playlists;
  setUp(() {
    store = MemoryKeyValueStore();
    playlists = PlaylistsStore(store: store, mutex: PrefsMutex());
  });

  PlaylistEntry entry(String url, [String? title]) =>
      PlaylistEntry(canonicalUrl: url, cachedTitle: title);

  group('PlaylistsStore', () {
    // **بلاغ المالك 2026-09-04:** «حذفتُ ملفات القائمة فبقيت في القائمة
    // ولا تعمل». الحذف كان يشذّب كل الفهارس إلا القوائم.
    test('removeFromAll يزيل المفتاح من كل القوائم ويعيد العدد', () async {
      final a = await playlists.create('أ');
      final b = await playlists.create('ب');
      await playlists.addItems(a.id, [entry('u1'), entry('u2')]);
      await playlists.addItems(b.id, [entry('u1'), entry('u3')]);

      expect(await playlists.removeFromAll(['u1']), 2);
      final all = await playlists.readAll();
      expect(all.firstWhere((p) => p.id == a.id).items.single.canonicalUrl,
          'u2');
      expect(all.firstWhere((p) => p.id == b.id).items.single.canonicalUrl,
          'u3');
    });

    test('removeFromAll يطابق مسار Lite القديم أيضاً', () async {
      final p = await playlists.create('مهاجرة');
      await playlists.addItems(p.id, [
        const PlaylistEntry(canonicalUrl: '', legacyPath: '/sd/old.mp4'),
      ]);
      expect(await playlists.removeFromAll(['/sd/old.mp4']), 1);
      expect((await playlists.readAll()).single.items, isEmpty);
    });

    test('removeFromAll يتجاهل المفاتيح الفارغة فلا يمسح المهاجَرة', () async {
      final p = await playlists.create('مهاجرة');
      await playlists.addItems(p.id, [
        const PlaylistEntry(canonicalUrl: '', legacyPath: '/sd/old.mp4'),
      ]);
      expect(await playlists.removeFromAll(['', '  x']), 0);
      expect((await playlists.readAll()).single.items, hasLength(1));
    });

    test('byName يجد بالاسم المشذّب ولا يخترع', () async {
      await playlists.create('دورة');
      expect((await playlists.byName('  دورة  '))?.name, 'دورة');
      expect(await playlists.byName('غير موجودة'), isNull);
      expect(await playlists.byName('   '), isNull);
    });

    test('إنشاء/تسمية/حذف', () async {
      final p = await playlists.create('مفضلاتي');
      expect((await playlists.readAll()).single.name, 'مفضلاتي');
      await playlists.rename(p.id, 'الاسم الجديد');
      expect((await playlists.byId(p.id))!.name, 'الاسم الجديد');
      await playlists.delete(p.id);
      expect(await playlists.readAll(), isEmpty);
    });

    test('إضافة عناصر مع منع التكرار بالرابط المُقنون', () async {
      final p = await playlists.create('ق');
      await playlists.addItems(p.id, [entry('u1'), entry('u2')]);
      await playlists.addItems(p.id, [entry('u1'), entry('u3')]);
      final saved = (await playlists.byId(p.id))!;
      expect(saved.items.map((e) => e.canonicalUrl), ['u1', 'u2', 'u3']);
    });

    test('إعادة الترتيب بالسحب', () async {
      final p = await playlists.create('ق');
      await playlists.addItems(p.id, [entry('a'), entry('b'), entry('c')]);
      await playlists.reorderItem(p.id, 0, 2);
      expect((await playlists.byId(p.id))!.items.map((e) => e.canonicalUrl),
          ['b', 'c', 'a']);
    });

    test('التثبيت وآخر تشغيل (م-37/ب)', () async {
      final p = await playlists.create('ق');
      await playlists.setPinned(p.id, true);
      await playlists.touchLastPlayed(p.id,
          at: DateTime.parse('2026-09-01T10:00:00'));
      final saved = (await playlists.byId(p.id))!;
      expect(saved.pinned, isTrue);
      expect(saved.lastPlayedAt, DateTime.parse('2026-09-01T10:00:00'));
    });

    test('إزالة عنصر', () async {
      final p = await playlists.create('ق');
      await playlists.addItems(p.id, [entry('a'), entry('b')]);
      await playlists.removeItem(p.id, 'a');
      expect((await playlists.byId(p.id))!.items.single.canonicalUrl, 'b');
    });

    test('استيراد صيغة Lite القديمة (videoPaths) ⇒ عناصر legacy', () async {
      await store.setString(
        PlaylistsStore.prefsKey,
        json.encode([
          {
            'name': 'قديمة',
            'createdAt': '2025-01-01T00:00:00',
            'videoPaths': [
              '/storage/emulated/0/Download/MeTube_Lite/فيديو_120001.mp4',
            ],
          },
        ]),
      );
      final all = await playlists.readAll();
      expect(all.single.name, 'قديمة');
      final item = all.single.items.single;
      expect(item.isLegacy, isTrue);
      expect(item.legacyPath, contains('فيديو_120001.mp4'));
      expect(all.single.createdAt.year, 2025);
    });

    test('roundtrip: الكتابة ثم القراءة تحفظ كل الحقول', () async {
      final p = await playlists.create('كاملة');
      await playlists.addItems(p.id, [
        const PlaylistEntry(
          canonicalUrl: 'https://youtu.be/dQw4w9WgXcQ',
          serverFilename: 'a.dQw4.mp4',
          cachedTitle: 'عنوان',
          cachedThumb: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        ),
      ]);
      final reread = (await playlists.byId(p.id))!.items.single;
      expect(reread.serverFilename, 'a.dQw4.mp4');
      expect(reread.cachedTitle, 'عنوان');
      expect(reread.cachedThumb, contains('hqdefault'));
      expect(reread.isLegacy, isFalse);
    });
  });
}
