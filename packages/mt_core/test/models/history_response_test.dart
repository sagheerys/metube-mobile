import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import '../fixtures/fixtures.dart';

void main() {
  group('HistoryResponse', () {
    test('an empty fixture is empty', () {
      final r = HistoryResponse.fromJson(loadFixture('history_empty.json'));
      expect(r.isEmpty, isTrue);
      expect(r.active, isEmpty);
    });

    test('missing lists come back empty, without throwing', () {
      final r = HistoryResponse.fromJson({'done': []});
      expect(r.queue, isEmpty);
      expect(r.pending, isEmpty);
    });

    test(
      'invalid entries, the ones that are not maps, are skipped silently',
      () {
        final r = HistoryResponse.fromJson({
          'done': [
            {'url': 'https://youtu.be/dQw4w9WgXcQ', 'status': 'finished'},
            'garbage-string',
            42,
          ],
          'queue': ['x'],
        });
        expect(r.done, hasLength(1));
        expect(r.queue, isEmpty);
      },
    );

    test('active = queue + pending', () {
      final r = HistoryResponse.fromJson(loadFixture('history_active.json'));
      expect(r.active, hasLength(3));
    });

    test('looksLikeMeTube requires both done and queue in a map', () {
      expect(
        HistoryResponse.looksLikeMeTube({'done': [], 'queue': []}),
        isTrue,
      );
      expect(HistoryResponse.looksLikeMeTube({'done': []}), isFalse);
      expect(HistoryResponse.looksLikeMeTube('<html></html>'), isFalse);
      expect(HistoryResponse.looksLikeMeTube(null), isFalse);
      expect(HistoryResponse.looksLikeMeTube([]), isFalse);
    });
  });
}
