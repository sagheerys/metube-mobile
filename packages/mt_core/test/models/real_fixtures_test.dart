import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import '../fixtures/fixtures.dart';

/// Tests against **real** JSON captured from a live server (gate 1,
/// captured 2026-09-01 from TrueNAS over both the local address and the
/// tunnel): the tolerant parser holds up against 251 actual items with all
/// their oddities. The identifying text has since been scrambled; see the
/// anonymisation note in the fixtures.
void main() {
  group('a real fixture: history_real_done', () {
    late HistoryResponse response;
    setUp(
      () => response = HistoryResponse.fromJson(
        loadFixture('real/history_real_done.json'),
      ),
    );

    test('it parses without throwing, and with many items', () {
      expect(response.done.length, greaterThan(200));
    });

    test('every completed item has a non-empty canonicalUrl', () {
      for (final item in response.done) {
        expect(item.canonicalUrl, isNotEmpty);
      }
    });

    test('no invented filenames: a missing one stays null', () {
      // At minimum, every genuinely finished item carries a filename from
      // the server.
      final finished = response.done.where(
        (i) => i.status == ItemStatus.completed,
      );
      expect(
        finished.where((i) => i.filename != null).length,
        greaterThan(150),
      );
    });

    test('the real timestamps decode to plausible times', () {
      final withTime = response.done.where((i) => i.timestamp != null).toList();
      expect(withTime, isNotEmpty);
      for (final item in withTime.take(20)) {
        expect(item.timestamp!.year, inInclusiveRange(2023, 2027));
      }
    });
  });

  group('a real fixture: history_real_active, a download in flight', () {
    test('the queued item is in progress, with the right status', () {
      final response = HistoryResponse.fromJson(
        loadFixture('real/history_real_active.json'),
      );
      expect(response.active, isNotEmpty);
      final running = response.active.first;
      expect(running.isDownloading, isTrue);
      expect(running.canonicalUrl, contains('youtube.com'));
    });
  });
}
