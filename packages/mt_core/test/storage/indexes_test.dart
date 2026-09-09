import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;
  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
  });

  const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

  group('OfflineIndex', () {
    test('put/get/remove بمفتاح canonicalUrl', () async {
      final index = OfflineIndex(store: store, mutex: mutex);
      await index.put(url, '/storage/emulated/0/Download/MeTube_Super/a.mp4');
      expect(await index.isOffline(url), isTrue);
      expect(await index.localPathOf(url), contains('a.mp4'));
      await index.removeKey(url);
      expect(await index.isOffline(url), isFalse);
    });

    test('يخزن تحت مفتاح prefs القديم offline_index', () async {
      final index = OfflineIndex(store: store, mutex: mutex);
      await index.put(url, '/x');
      expect(store.snapshot.keys, contains('offline_index'));
    });

    test('JSON معطوب ⇒ خريطة فارغة لا انهيار', () async {
      await store.setString('offline_index', '{broken');
      final index = OfflineIndex(store: store, mutex: mutex);
      expect(await index.readAll(), isEmpty);
    });
  });

  group('ArtworkIndex', () {
    test('غلاف SoundCloud محفوظ ومسترجع', () async {
      final index = ArtworkIndex(store: store, mutex: mutex);
      const sc = 'https://soundcloud.com/artist/track';
      await index.put(sc, 'https://i1.sndcdn.com/art-t500x500.jpg');
      expect(await index.artworkOf(sc), contains('t500x500'));
      expect(await index.artworkOf('https://other'), isNull);
    });

    /// **حرّاس تسريب المصغرات (عطل المالك 2026-09-08).** الحذف كان
    /// يزيل السطر من الفهرس ويترك ملف JPG يتيماً — وبعد نقل المصغرات
    /// إلى `filesDir` لم يبقَ من يكنسه: ٣٠KB تتراكم مع كل حذف.
    group('removeKeysAndFiles', () {
      late Directory dir;
      setUp(() => dir = Directory.systemTemp.createTempSync('mtf_art_'));
      tearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      File thumbAt(String name) =>
          File('${dir.path}/$name.jpg')..writeAsStringSync('jpeg');

      test('يحذف الملف من القرص لا المدخلة وحدها', () async {
        final index = ArtworkIndex(store: store, mutex: mutex);
        final thumb = thumbAt('a');
        await index.put(url, thumb.path);

        await index.removeKeysAndFiles([url]);

        expect(thumb.existsSync(), isFalse, reason: 'الملف نفسه يزول');
        expect(await index.artworkOf(url), isNull);
      });

      test('رابط بعيد لا يُعامل معاملة المسار', () async {
        final index = ArtworkIndex(store: store, mutex: mutex);
        await index.put(url, 'https://i.ytimg.com/vi/x/hq.jpg');
        // لا ملف ليُحذف — والمهم ألا ينهار على قيمة ليست مساراً.
        await index.removeKeysAndFiles([url]);
        expect(await index.artworkOf(url), isNull);
      });

      test('غلاف يشترك فيه مفتاح باقٍ لا يُحذف', () async {
        final index = ArtworkIndex(store: store, mutex: mutex);
        final shared = thumbAt('shared');
        await index.put('u1', shared.path);
        await index.put('u2', shared.path);

        await index.removeKeysAndFiles(['u1']);

        expect(
          shared.existsSync(),
          isTrue,
          reason: 'وإلا فقد u2 غلافه لأن جاره حُذف',
        );
        expect(await index.artworkOf('u2'), shared.path);
      });

      test('ملف مفقود أصلاً ⇒ لا انهيار، والمدخلة تزول', () async {
        final index = ArtworkIndex(store: store, mutex: mutex);
        await index.put(url, '${dir.path}/gone.jpg');
        await index.removeKeysAndFiles([url]);
        expect(await index.readAll(), isEmpty);
      });
    });
  });

  group('TagsIndex', () {
    test('toggle يضيف ثم يزيل، والفارغ يُحذف من الخريطة', () async {
      final index = TagsIndex(store: store, mutex: mutex);
      await index.toggleTag(url, 'أناشيد');
      expect(await index.tagsOf(url), ['أناشيد']);
      await index.toggleTag(url, 'أناشيد');
      expect(await index.tagsOf(url), isEmpty);
      expect(await index.readAll(), isEmpty);
    });

    test('العدادات والتصفية', () async {
      final index = TagsIndex(store: store, mutex: mutex);
      await index.toggleTag('u1', 'وثائقي');
      await index.toggleTag('u2', 'وثائقي');
      await index.toggleTag('u2', 'قرآن');
      expect(await index.allTagsWithCounts(), {'وثائقي': 2, 'قرآن': 1});
      expect(await index.urlsWithTag('وثائقي'), ['u1', 'u2']);
    });

    test('إعادة تسمية وحذف وسم — الوسائط تبقى', () async {
      final index = TagsIndex(store: store, mutex: mutex);
      await index.toggleTag('u1', 'قديم');
      await index.toggleTag('u1', 'ثابت');
      await index.renameTag('قديم', 'جديد');
      expect(await index.tagsOf('u1'), containsAll(['جديد', 'ثابت']));
      await index.deleteTag('جديد');
      expect(await index.tagsOf('u1'), ['ثابت']);
    });
  });
}
