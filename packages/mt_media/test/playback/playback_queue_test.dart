import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';

PlaylistItem _item(String id) => PlaylistItem(
  canonicalUrl: 'https://x/$id',
  title: id,
  serverFilename: '$id.mp4',
);

final _five = [
  for (final id in ['a', 'b', 'c', 'd', 'e']) _item(id),
];

void main() {
  group('الترتيب العادي', () {
    test('يبدأ من الفهرس المطلوب', () {
      final queue = PlaybackQueue(items: _five, index: 2);
      expect(queue.current!.title, 'c');
      expect(queue.index, 2);
    });

    test('الفهرس خارج المدى يُقصّ', () {
      expect(PlaybackQueue(items: _five, index: 99).index, 4);
      expect(PlaybackQueue(items: _five, index: -3).index, 0);
    });

    test('قائمة فارغة: لا حالي ولا تالٍ', () {
      final queue = PlaybackQueue(items: const []);
      expect(queue.current, isNull);
      expect(queue.index, -1);
      expect(queue.nextIndex(PlayMode.autoNext), isNull);
    });
  });

  group('أوضاع التشغيل (م-20)', () {
    test('تلقائي: التالي ثم يتوقف عند النهاية', () {
      final queue = PlaybackQueue(items: _five, index: 3);
      expect(queue.nextIndex(PlayMode.autoNext), 4);
      queue.jumpTo(4);
      expect(queue.nextIndex(PlayMode.autoNext), isNull);
    });

    test('تكرار الكل يلتف من النهاية للبداية والعكس', () {
      final queue = PlaybackQueue(items: _five, index: 4);
      expect(queue.nextIndex(PlayMode.repeatAll), 0);
      queue.jumpTo(0);
      expect(queue.previousIndex(PlayMode.repeatAll), 4);
    });

    test('إيقاف عند النهاية لا يلتف', () {
      final queue = PlaybackQueue(items: _five, index: 4);
      expect(queue.nextIndex(PlayMode.stopAtEnd), isNull);
    });

    test('تكرار واحد: تلقائياً يعيد نفسه', () {
      final queue = PlaybackQueue(items: _five, index: 1);
      expect(queue.nextIndex(PlayMode.repeatOne), 1);
    });

    test('تكرار واحد لا يحبس المستخدم حين يضغط «التالي»', () {
      final queue = PlaybackQueue(items: _five, index: 1);
      expect(queue.nextIndex(PlayMode.repeatOne, userInitiated: true), 2);
      queue.jumpTo(4);
      expect(queue.nextIndex(PlayMode.repeatOne, userInitiated: true), 0);
    });

    test('السابق من أول القائمة بلا تكرار = لا شيء', () {
      final queue = PlaybackQueue(items: _five);
      expect(queue.previousIndex(PlayMode.autoNext), isNull);
    });
  });

  group('العشوائي', () {
    test('يبدأ من العنصر الحالي ويشمل كل العناصر مرة واحدة', () {
      final queue = PlaybackQueue(
        items: _five,
        index: 3,
        shuffle: true,
        random: Random(7),
      );
      expect(queue.current!.title, 'd');
      expect(queue.ordered.first.title, 'd');
      expect(queue.ordered.map((i) => i.title).toSet().length, 5);
    });

    test('المرور على كل العناصر بلا تكرار حتى النهاية', () {
      final queue = PlaybackQueue(
        items: _five,
        shuffle: true,
        random: Random(3),
      );
      final visited = <String>[queue.current!.title];
      while (queue.moveNext(PlayMode.autoNext)) {
        visited.add(queue.current!.title);
      }
      expect(visited.toSet().length, 5);
    });

    test('إطفاء العشوائي يعيد الترتيب الأصلي مع بقاء العنصر الحالي', () {
      final queue = PlaybackQueue(
        items: _five,
        index: 2,
        shuffle: true,
        random: Random(11),
      );
      queue.setShuffle(false);
      expect(queue.current!.title, 'c');
      expect(queue.ordered.map((i) => i.title), ['a', 'b', 'c', 'd', 'e']);
      expect(queue.nextIndex(PlayMode.autoNext), 3);
    });
  });

  group('الحذف (تخطي معطوب / إزالة من الورقة)', () {
    test('حذف غير الحالي يبقي العنصر الحالي نفسه', () {
      final queue = PlaybackQueue(items: _five, index: 3);
      expect(queue.removeAt(0), isTrue);
      expect(queue.current!.title, 'd');
      expect(queue.length, 4);
    });

    test('حذف الحالي ينتقل لما حلّ محله', () {
      final queue = PlaybackQueue(items: _five, index: 2);
      queue.removeAt(2);
      expect(queue.current!.title, 'd');
    });

    test('حذف آخر عنصر وهو الحالي يرجع للأخير الباقي', () {
      final queue = PlaybackQueue(items: _five, index: 4);
      queue.removeAt(4);
      expect(queue.current!.title, 'd');
    });

    test('حذف الجميع يترك الطابور فارغاً', () {
      final queue = PlaybackQueue(items: [_item('only')]);
      queue.removeAt(0);
      expect(queue.isEmpty, isTrue);
      expect(queue.current, isNull);
    });

    test('فهرس خارج المدى يُرفض', () {
      final queue = PlaybackQueue(items: _five);
      expect(queue.removeAt(9), isFalse);
      expect(queue.length, 5);
    });
  });

  test('jumpTo يرفض ما ليس في الطابور', () {
    final queue = PlaybackQueue(items: _five);
    expect(queue.jumpTo(2), isTrue);
    expect(queue.jumpTo(50), isFalse);
    expect(queue.index, 2);
  });
}
