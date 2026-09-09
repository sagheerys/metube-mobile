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
    test('put, get and remove, keyed by canonicalUrl', () async {
      final index = OfflineIndex(store: store, mutex: mutex);
      await index.put(url, '/storage/emulated/0/Download/MeTube_Super/a.mp4');
      expect(await index.isOffline(url), isTrue);
      expect(await index.localPathOf(url), contains('a.mp4'));
      await index.removeKey(url);
      expect(await index.isOffline(url), isFalse);
    });

    test('it stores under the old offline_index preference key', () async {
      final index = OfflineIndex(store: store, mutex: mutex);
      await index.put(url, '/x');
      expect(store.snapshot.keys, contains('offline_index'));
    });

    test('corrupt JSON gives an empty map, not a crash', () async {
      await store.setString('offline_index', '{broken');
      final index = OfflineIndex(store: store, mutex: mutex);
      expect(await index.readAll(), isEmpty);
    });
  });

  group('ArtworkIndex', () {
    test('a SoundCloud cover is stored and read back', () async {
      final index = ArtworkIndex(store: store, mutex: mutex);
      const sc = 'https://soundcloud.com/artist/track';
      await index.put(sc, 'https://i1.sndcdn.com/art-t500x500.jpg');
      expect(await index.artworkOf(sc), contains('t500x500'));
      expect(await index.artworkOf('https://other'), isNull);
    });

    /// **Thumbnail leak guards (defect found 2026-09-08).** Deletion
    /// removed the line from the index and left an orphan JPG, and once
    /// thumbnails moved to `filesDir` nothing swept them: 30KB accumulating
    /// with every deletion.
    group('removeKeysAndFiles', () {
      late Directory dir;
      setUp(() => dir = Directory.systemTemp.createTempSync('mtf_art_'));
      tearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });

      File thumbAt(String name) =>
          File('${dir.path}/$name.jpg')..writeAsStringSync('jpeg');

      test('it deletes the file from disk, not only the entry', () async {
        final index = ArtworkIndex(store: store, mutex: mutex);
        final thumb = thumbAt('a');
        await index.put(url, thumb.path);

        await index.removeKeysAndFiles([url]);

        expect(thumb.existsSync(), isFalse, reason: 'الملف نفسه يزول');
        expect(await index.artworkOf(url), isNull);
      });

      test('a remote URL is not treated as a path', () async {
        final index = ArtworkIndex(store: store, mutex: mutex);
        await index.put(url, 'https://i.ytimg.com/vi/x/hq.jpg');
        // There is no file to delete, and what matters is that it does not
        // crash on a value that is not a path.
        await index.removeKeysAndFiles([url]);
        expect(await index.artworkOf(url), isNull);
      });

      test('a cover shared with a surviving key is not deleted', () async {
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

      test(
        'a file already missing does not crash, and the entry goes',
        () async {
          final index = ArtworkIndex(store: store, mutex: mutex);
          await index.put(url, '${dir.path}/gone.jpg');
          await index.removeKeysAndFiles([url]);
          expect(await index.readAll(), isEmpty);
        },
      );
    });
  });

  group('TagsIndex', () {
    test('toggle adds then removes, and an empty set leaves the map', () async {
      final index = TagsIndex(store: store, mutex: mutex);
      await index.toggleTag(url, 'أناشيد');
      expect(await index.tagsOf(url), ['أناشيد']);
      await index.toggleTag(url, 'أناشيد');
      expect(await index.tagsOf(url), isEmpty);
      expect(await index.readAll(), isEmpty);
    });

    test('the counters and the filtering', () async {
      final index = TagsIndex(store: store, mutex: mutex);
      await index.toggleTag('u1', 'وثائقي');
      await index.toggleTag('u2', 'وثائقي');
      await index.toggleTag('u2', 'قرآن');
      expect(await index.allTagsWithCounts(), {'وثائقي': 2, 'قرآن': 1});
      expect(await index.urlsWithTag('وثائقي'), ['u1', 'u2']);
    });

    test('renaming and deleting a tag; the media stay', () async {
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
