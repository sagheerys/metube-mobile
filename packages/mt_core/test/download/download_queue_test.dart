import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('DownloadQueue (§3)', () {
    test('المفرد يتقدم على أعضاء الدفعات', () {
      final queue = DownloadQueue()
        ..enqueue('b1', isBatchMember: true)
        ..enqueue('b2', isBatchMember: true)
        ..enqueue('s1', isBatchMember: false);
      expect(queue.takeNext(), 's1');
      expect(queue.takeNext(), 'b1');
      expect(queue.takeNext(), 'b2');
      expect(queue.takeNext(), isNull);
    });

    test('FIFO داخل كل صنف', () {
      final queue = DownloadQueue()
        ..enqueue('s1', isBatchMember: false)
        ..enqueue('s2', isBatchMember: false);
      expect(queue.takeNext(), 's1');
      expect(queue.takeNext(), 's2');
    });

    test('remove يلغي المنتظر', () {
      final queue = DownloadQueue()
        ..enqueue('a', isBatchMember: false)
        ..enqueue('b', isBatchMember: true);
      expect(queue.remove('b'), isTrue);
      expect(queue.remove('غائب'), isFalse);
      expect(queue.pendingIds, ['a']);
      expect(queue.length, 1);
    });
  });
}
