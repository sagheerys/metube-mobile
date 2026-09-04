import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **سؤال المالك 2026-09-02:** «عند تحميل دورة من يوتيوب هل تُجمع مع
/// بعضها؟» — كان الجواب لا: `isBatchMember` يرتّب الطابور فقط.
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

  test('الدفعة تُجمع في قائمة واحدة باسم قائمة المصدر', () async {
    final playlist = await collector.begin('دورة Flutter', ['t1', 't2', 't3']);
    expect(playlist.name, 'دورة Flutter');

    await collector.onFinished(done('t1', 'https://y/1', title: 'الدرس 1'));
    await collector.onFinished(done('t2', 'https://y/2', title: 'الدرس 2'));
    await collector.onFinished(done('t3', 'https://y/3', title: 'الدرس 3'));

    final saved = (await playlists.readAll()).single;
    expect(saved.name, 'دورة Flutter');
    expect(saved.items.map((e) => e.canonicalUrl),
        ['https://y/1', 'https://y/2', 'https://y/3']);
    expect(saved.items.first.cachedTitle, 'الدرس 1');
    expect(saved.items.first.serverFilename, 't1.mp4');
  });

  test('الترتيب من المصدر لا من الاكتمال', () async {
    await collector.begin('دورة', ['t1', 't2', 't3']);
    // الثالث اكتمل أولاً (الأول تعثّر وأُعيد).
    await collector.onFinished(done('t3', 'https://y/3'));
    await collector.onFinished(done('t1', 'https://y/1'));
    await collector.onFinished(done('t2', 'https://y/2'));

    final saved = (await playlists.readAll()).single;
    expect(saved.items.map((e) => e.canonicalUrl),
        ['https://y/1', 'https://y/2', 'https://y/3']);
  });

  test('عضو ساقط لا يعطّل القائمة ولا يترك مكاناً فارغاً', () async {
    await collector.begin('دورة', ['t1', 't2']);
    await collector.onDropped('t1'); // فشل
    await collector.onFinished(done('t2', 'https://y/2'));

    final saved = (await playlists.readAll()).single;
    expect(saved.items.map((e) => e.canonicalUrl), ['https://y/2']);
  });

  test('سقوط كل الأعضاء ⇒ لا تبقى قائمة فارغة شبح', () async {
    await collector.begin('دورة فاشلة', ['t1', 't2']);
    await collector.onDropped('t1');
    await collector.onDropped('t2');
    expect(await playlists.readAll(), isEmpty);
  });

  test('كل كتابة تُخبِر الواجهة (وإلا بقيت القائمة غير مرئية)', () async {
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
  });

  test('مهمة ليست من الدفعة لا تُضاف لشيء', () async {
    await collector.begin('دورة', ['t1']);
    await collector.onFinished(done('غريب', 'https://y/x'));
    final saved = (await playlists.readAll()).single;
    expect(saved.items, isEmpty);
  });

  // **بلاغ المالك 2026-09-04:** «حمّلت القائمة من يوتيوب مرة أخرى
  // فظهرت في قائمة جديدة وصار عندي قائمتان». `begin` كانت تُنشئ قائمة
  // في كل مرة بلا سؤال.
  group('إعادة تحميل المصدر نفسه', () {
    test('لا تُستنسخ القائمة — نفس الاسم يعني نفس القائمة', () async {
      await collector.begin('دورة', ['t1', 't2']);
      await collector.onFinished(done('t1', 'https://y/1'));
      await collector.onFinished(done('t2', 'https://y/2'));

      await collector.begin('دورة', ['r1', 'r2']);
      await collector.onFinished(done('r1', 'https://y/1'));
      await collector.onFinished(done('r2', 'https://y/2'));

      final all = await playlists.readAll();
      expect(all, hasLength(1), reason: 'قائمة واحدة لا قائمتان');
      expect(all.single.items.map((e) => e.canonicalUrl),
          ['https://y/1', 'https://y/2'],
          reason: 'ولا مداخل مكررة داخلها');
    });

    test('الجديد يُلحق بآخر القائمة لا برأسها', () async {
      await collector.begin('دورة', ['t1']);
      await collector.onFinished(done('t1', 'https://y/1'));

      await collector.begin('دورة', ['r1', 'r2']);
      await collector.onFinished(done('r2', 'https://y/3'));
      await collector.onFinished(done('r1', 'https://y/2'));

      final saved = (await playlists.readAll()).single;
      expect(saved.items.map((e) => e.canonicalUrl),
          ['https://y/1', 'https://y/2', 'https://y/3'],
          reason: 'الترتيب يُزاح بما كان في القائمة قبل الدفعة');
    });

    test('قائمة كانت موجودة لا تُحذف لو سقط كل أعضاء الدفعة', () async {
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
