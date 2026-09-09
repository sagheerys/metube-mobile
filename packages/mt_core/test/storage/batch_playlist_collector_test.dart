import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **Asked 2026-09-02:** "when I download a course from YouTube, are they
/// grouped together?" The answer was no: `isBatchMember` only ordered the
/// queue.
void main() {
  late PlaylistsStore playlists;
  late BatchPlaylistCollector collector;

  DownloadTask done(String id, String url, {String? title}) => DownloadTask(
    id: id,
    inputUrl: url,
    quality: Quality.best,
    canonicalUrl: url,
    serverFilename: '$id.mp4',
    title: title ?? id,
    phase: TaskPhase.completed,
    isBatchMember: true,
  );

  setUp(() {
    playlists = PlaylistsStore(
      store: MemoryKeyValueStore(),
      mutex: PrefsMutex(),
    );
    collector = BatchPlaylistCollector(playlists: playlists);
  });

  test(
    'the batch is collected into one playlist, named after the source',
    () async {
      final playlist = await collector.begin('دورة Flutter', [
        't1',
        't2',
        't3',
      ]);
      expect(playlist.name, 'دورة Flutter');

      await collector.onFinished(done('t1', 'https://y/1', title: 'الدرس 1'));
      await collector.onFinished(done('t2', 'https://y/2', title: 'الدرس 2'));
      await collector.onFinished(done('t3', 'https://y/3', title: 'الدرس 3'));

      final saved = (await playlists.readAll()).single;
      expect(saved.name, 'دورة Flutter');
      expect(saved.items.map((e) => e.canonicalUrl), [
        'https://y/1',
        'https://y/2',
        'https://y/3',
      ]);
      expect(saved.items.first.cachedTitle, 'الدرس 1');
      expect(saved.items.first.serverFilename, 't1.mp4');
    },
  );

  test(
    'the order comes from the source, not from what finished first',
    () async {
      await collector.begin('دورة', ['t1', 't2', 't3']);
      // The third completed first (the first stumbled and was retried).
      await collector.onFinished(done('t3', 'https://y/3'));
      await collector.onFinished(done('t1', 'https://y/1'));
      await collector.onFinished(done('t2', 'https://y/2'));

      final saved = (await playlists.readAll()).single;
      expect(saved.items.map((e) => e.canonicalUrl), [
        'https://y/1',
        'https://y/2',
        'https://y/3',
      ]);
    },
  );

  test(
    'a dropped member neither breaks the playlist nor leaves a gap',
    () async {
      await collector.begin('دورة', ['t1', 't2']);
      await collector.onDropped('t1'); // failed
      await collector.onFinished(done('t2', 'https://y/2'));

      final saved = (await playlists.readAll()).single;
      expect(saved.items.map((e) => e.canonicalUrl), ['https://y/2']);
    },
  );

  test('every member dropping leaves no ghost empty playlist', () async {
    await collector.begin('دورة فاشلة', ['t1', 't2']);
    await collector.onDropped('t1');
    await collector.onDropped('t2');
    expect(await playlists.readAll(), isEmpty);
  });

  test(
    'every write notifies the interface, or the playlist stays invisible',
    () async {
      var notified = 0;
      final watched = BatchPlaylistCollector(
        playlists: playlists,
        onChanged: () => notified++,
      );
      await watched.begin('دورة', ['t1', 't2']);
      expect(notified, 1, reason: 'الإنشاء وحده يستحق إظهار البطاقة');
      await watched.onFinished(done('t1', 'https://y/1'));
      await watched.onDropped('t2');
      expect(notified, 3);
    },
  );

  test('a task outside the batch is added to nothing', () async {
    await collector.begin('دورة', ['t1']);
    await collector.onFinished(done('غريب', 'https://y/x'));
    final saved = (await playlists.readAll()).single;
    expect(saved.items, isEmpty);
  });

  // **Field report 2026-09-04:** "I downloaded the YouTube playlist again
  // and it appeared as a new playlist, so now I have two." `begin` used to
  // create a playlist every time without asking.
  group('downloading the same source again', () {
    test(
      'the playlist is not duplicated: the same name means the same playlist',
      () async {
        await collector.begin('دورة', ['t1', 't2']);
        await collector.onFinished(done('t1', 'https://y/1'));
        await collector.onFinished(done('t2', 'https://y/2'));

        await collector.begin('دورة', ['r1', 'r2']);
        await collector.onFinished(done('r1', 'https://y/1'));
        await collector.onFinished(done('r2', 'https://y/2'));

        final all = await playlists.readAll();
        expect(all, hasLength(1), reason: 'قائمة واحدة لا قائمتان');
        expect(all.single.items.map((e) => e.canonicalUrl), [
          'https://y/1',
          'https://y/2',
        ], reason: 'ولا مداخل مكررة داخلها');
      },
    );

    test('new items are appended to the end, not to the head', () async {
      await collector.begin('دورة', ['t1']);
      await collector.onFinished(done('t1', 'https://y/1'));

      await collector.begin('دورة', ['r1', 'r2']);
      await collector.onFinished(done('r2', 'https://y/3'));
      await collector.onFinished(done('r1', 'https://y/2'));

      final saved = (await playlists.readAll()).single;
      expect(saved.items.map((e) => e.canonicalUrl), [
        'https://y/1',
        'https://y/2',
        'https://y/3',
      ], reason: 'الترتيب يُزاح بما كان في القائمة قبل الدفعة');
    });

    test('a playlist that already existed is not deleted when every batch member drops', () async {
      await collector.begin('دورة', ['t1']);
      await collector.onFinished(done('t1', 'https://y/1'));

      await collector.begin('دورة', ['r1']);
      await collector.onDropped('r1');

      final all = await playlists.readAll();
      expect(all, hasLength(1));
      expect(all.single.items, hasLength(1));
    });
  });
}
