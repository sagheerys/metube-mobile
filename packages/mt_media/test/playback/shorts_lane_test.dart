import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

PlaylistItem _short(String id) => PlaylistItem(
      canonicalUrl: 'https://x/$id',
      title: id,
      serverFilename: '$id.mp4',
      duration: const Duration(seconds: 45),
      aspectRatio: 0.5625,
    );

PlaylistItem _wide(String id) => PlaylistItem(
      canonicalUrl: 'https://x/$id',
      title: id,
      serverFilename: '$id.mp4',
      duration: const Duration(minutes: 12),
      aspectRatio: 1.77,
    );

PlaylistItem _audio(String id) => PlaylistItem(
      canonicalUrl: 'https://x/$id',
      title: id,
      serverFilename: '$id.mp3',
      isAudio: true,
      duration: const Duration(seconds: 30),
      aspectRatio: 0.5,
    );

PlaylistItem _unknown(String id) =>
    PlaylistItem(canonicalUrl: 'https://x/$id', title: id);

void main() {
  group('مسار القِصار المصفّى (م-35)', () {
    test('يأخذ العمودية القصيرة فقط بترتيب القائمة', () {
      final source = [
        _wide('a'),
        _short('b'),
        _audio('c'),
        _short('d'),
        _unknown('e'),
      ];
      final lane = ShortsLane.from(source);
      expect(lane.items.map((i) => i.title), ['b', 'd']);
      expect(lane.sourceIndices, [1, 3]);
      expect(lane.length, 2, reason: 'العداد يعدّ القِصار وحدها');
    });

    test('الصوتي لا يدخل المسار مهما كانت مدته ونسبته', () {
      expect(ShortsLane.from([_audio('a')]).isEmpty, isTrue);
    });

    test('المجهول الأبعاد ليس قصيراً — لا تخمين', () {
      expect(ShortsLane.from([_unknown('a')]).isEmpty, isTrue);
    });

    test('العمودي الطويل (>3 دقائق) خارج المسار', () {
      const longVertical = PlaylistItem(
        canonicalUrl: 'https://x/l',
        title: 'l',
        duration: Duration(minutes: 4),
        aspectRatio: 0.5625,
      );
      expect(ShortsLane.from(const [longVertical]).isEmpty, isTrue);
    });

    test('موضع عنصر داخل المسار', () {
      final lane = ShortsLane.from([_wide('a'), _short('b'), _short('d')]);
      expect(lane.laneIndexOf('https://x/d'), 1);
      expect(lane.laneIndexOf('https://x/a'), -1);
    });

    test('«متابعة بقية القائمة» تختار أول غير قصير بعد آخر قصير', () {
      final source = [_short('a'), _short('b'), _wide('c'), _audio('d')];
      final lane = ShortsLane.from(source);
      expect(lane.nextNonShortIndex(source), 2);
    });

    test('لا غير-قصير بعده ⇒ يلتف لأول غير قصير في القائمة', () {
      final source = [_wide('a'), _short('b'), _short('c')];
      final lane = ShortsLane.from(source);
      expect(lane.nextNonShortIndex(source), 0);
    });

    test('قائمة كلها قِصار ⇒ لا شيء لمتابعته', () {
      final source = [_short('a'), _short('b')];
      expect(ShortsLane.from(source).nextNonShortIndex(source), isNull);
    });
  });

  group('MediaShapeIndex', () {
    late MediaShapeIndex index;
    setUp(() => index = MediaShapeIndex(
          store: MemoryKeyValueStore(),
          mutex: PrefsMutex(),
        ));

    test('يحفظ الأبعاد ويقرؤها', () async {
      await index.remember(
          'https://x/1', const Duration(seconds: 50), 0.5625);
      final shape = await index.valueOf('https://x/1');
      expect(shape!.duration, const Duration(seconds: 50));
      expect(shape.aspectRatio, closeTo(0.5625, 0.0001));
      expect(shape.isVertical, isTrue);
      expect(shape.isShortForm, isTrue);
    });

    test('العرضي والطويل ليسا قِصاراً', () {
      const wide = MediaShape(
          duration: Duration(seconds: 30), aspectRatio: 1.77);
      const longVertical = MediaShape(
          duration: Duration(minutes: 9), aspectRatio: 0.56);
      expect(wide.isShortForm, isFalse);
      expect(longVertical.isShortForm, isFalse);
    });

    test('مدة صفرية لا تُحفظ', () async {
      await index.remember('https://x/2', Duration.zero, 0.5);
      expect(await index.valueOf('https://x/2'), isNull);
    });

    test('قيمة تالفة في الفهرس تُتجاهل', () {
      expect(index.decodeValue({'d': 'ليس رقماً', 'r': 1}), isNull);
      expect(index.decodeValue('نص'), isNull);
    });
  });
}
