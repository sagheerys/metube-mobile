import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

void main() {
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;

  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
  });

  group('PlaybackPositionStore', () {
    late PlaybackPositionStore positions;
    setUp(() => positions = PlaybackPositionStore(store: store, mutex: mutex));

    test('المفتاح هو playback_pos_<canonicalUrl> (§5.1)', () {
      expect(positions.keyOf('https://x/1'), 'playback_pos_https://x/1');
    });

    test('يحفظ ويقرأ الموضع', () async {
      await positions.save('u', const Duration(seconds: 42));
      expect(await positions.positionOf('u'), const Duration(seconds: 42));
    });

    test('البدايات العابرة (<5 ثوانٍ) لا تُحفظ', () async {
      await positions.save('u', const Duration(seconds: 30));
      await positions.save('u', const Duration(seconds: 2));
      expect(await positions.positionOf('u'), isNull);
    });

    test('قرب النهاية يُمسح ليبدأ من أوله لاحقاً', () async {
      await positions.save(
        'u',
        const Duration(minutes: 9, seconds: 55),
        duration: const Duration(minutes: 10),
      );
      expect(await positions.positionOf('u'), isNull);
    });

    test('وسط المقطع مع مدة معروفة يُحفظ', () async {
      await positions.save(
        'u',
        const Duration(minutes: 4),
        duration: const Duration(minutes: 10),
      );
      expect(await positions.positionOf('u'), const Duration(minutes: 4));
    });

    test('البث والمحلي يتشاركان الموضع لأن المفتاح واحد (م-19)', () async {
      const url = 'https://youtube.com/watch?v=abc';
      await positions.save(url, const Duration(seconds: 90));
      // The same item from a different source means the same canonicalUrl,
      // and so the same position.
      expect(await positions.positionOf(url), const Duration(seconds: 90));
    });

    test('clearAll يمسح المواضع وحدها', () async {
      await store.setString('server_url', 'https://srv');
      await positions.save('a', const Duration(seconds: 20));
      await positions.save('b', const Duration(seconds: 30));
      await positions.clearAll();
      expect(await positions.positionOf('a'), isNull);
      expect(await store.getString('server_url'), 'https://srv');
    });
  });

  group('PlaybackPrefs', () {
    late PlaybackPrefs prefs;
    setUp(() => prefs = PlaybackPrefs(store: store, mutex: mutex));

    test('الافتراضات بلا تخزين', () async {
      expect(await prefs.playMode(), PlayMode.autoNext);
      expect(await prefs.speed(), 1.0);
      expect(await prefs.shuffle(), isFalse);
    });

    test('وضع مخصص لقائمة يغلب العام', () async {
      await prefs.setPlayMode(PlayMode.repeatAll);
      await prefs.setPlayMode(PlayMode.repeatOne, playlistId: 'p1');
      expect(await prefs.playMode(), PlayMode.repeatAll);
      expect(await prefs.playMode(playlistId: 'p1'), PlayMode.repeatOne);
      expect(await prefs.playMode(playlistId: 'p2'), PlayMode.repeatAll);
    });

    test('السرعة تُقصّ داخل المدى المسموح', () async {
      await prefs.setSpeed(9);
      expect(await prefs.speed(), 3.0);
      await prefs.setSpeed(0.01);
      expect(await prefs.speed(), 0.25);
    });

    test('العشوائي يُحفظ', () async {
      await prefs.setShuffle(true);
      expect(await prefs.shuffle(), isTrue);
    });

    test('دورة زر الوضع تمر على الأربعة وتعود', () {
      var mode = PlayMode.autoNext;
      final seen = <PlayMode>[mode];
      for (var i = 0; i < 3; i++) {
        mode = mode.next;
        seen.add(mode);
      }
      expect(seen.toSet().length, 4);
      expect(mode.next, PlayMode.autoNext);
    });

    test('قيمة وضع غير معروفة تسقط للافتراضي', () {
      expect(PlayMode.fromWire('nonsense'), PlayMode.autoNext);
      expect(PlayMode.fromWire(null), PlayMode.autoNext);
      expect(PlayMode.fromWire('repeat_all'), PlayMode.repeatAll);
    });
  });

  group('AudioStateStore (م-21: الاستعادة بعد إعادة التشغيل)', () {
    late AudioStateStore states;
    setUp(() => states = AudioStateStore(store: store, mutex: mutex));

    const items = [
      PlaylistItem(canonicalUrl: 'https://x/1', title: 'أول', isAudio: true),
      PlaylistItem(canonicalUrl: 'https://x/2', title: 'ثانٍ'),
    ];

    test('لا حالة محفوظة ⇒ null', () async {
      expect(await states.read(), isNull);
    });

    test('كتابة وقراءة الجلسة كاملة', () async {
      await states.write(
        const AudioSessionSnapshot(
          items: items,
          index: 1,
          position: Duration(seconds: 75),
          playlistId: 'p9',
        ),
      );
      final back = (await states.read())!;
      expect(back.items.map((i) => i.title), ['أول', 'ثانٍ']);
      expect(back.index, 1);
      expect(back.position, const Duration(seconds: 75));
      expect(back.playlistId, 'p9');
    });

    test('فهرس خارج المدى يُقصّ عند القراءة', () async {
      await states.write(const AudioSessionSnapshot(items: items, index: 7));
      expect((await states.read())!.index, 1);
    });

    test('حالة تالفة لا تكسر الإقلاع', () async {
      await store.setString(AudioStateStore.key, 'ليس JSON');
      expect(await states.read(), isNull);
    });

    test('clear يمحو الحالة (شرط عدم عودة المشغل الشبح)', () async {
      await states.write(const AudioSessionSnapshot(items: items, index: 0));
      await states.clear();
      expect(await states.read(), isNull);
    });
  });
}
