import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import '../fixtures/fixtures.dart';

void main() {
  group('HistoryItem.fromJson — fixture: history_active', () {
    late HistoryResponse response;
    setUp(
      () => response = HistoryResponse.fromJson(
        loadFixture('history_active.json'),
      ),
    );

    test('a percent above 1 is divided by 100', () {
      expect(response.queue.first.progress, closeTo(0.453, 0.0001));
    });

    test('downloading ⇒ inProgress', () {
      expect(response.queue.first.status, ItemStatus.inProgress);
      expect(response.queue.first.isDownloading, isTrue);
    });

    test('the trap: a missing filename stays null and is never made from the title', () {
      expect(response.queue.first.filename, isNull);
    });

    test('state=preparing, a synonym, means inProgress', () {
      expect(response.queue[1].status, ItemStatus.inProgress);
    });

    test('pending: _id stands in for id, and name for title', () {
      final item = response.pending.single;
      expect(item.id, 'pend-1');
      expect(item.title, 'قائمة الانتظار — مقطع معلق');
      expect(item.status, ItemStatus.inProgress);
    });

    test(
      'no ytimg outside YouTube: a SoundCloud item with no image gives null',
      () {
        expect(response.queue[1].thumbnail, isNull);
      },
    );
  });

  group('HistoryItem.fromJson — fixture: history_done', () {
    late List<HistoryItem> done;
    setUp(
      () =>
          done = HistoryResponse.fromJson(loadFixture('history_done.json'))
              .done,
    );

    test('finished means completed, with a real filename from the server', () {
      expect(done[0].status, ItemStatus.completed);
      expect(done[0].filename, endsWith('.dQw4w9WgXcQ.mp4'));
    });

    test(
      'YouTube with no thumbnail field derives an i.ytimg URL from the id',
      () {
        expect(
          done[0].thumbnail,
          'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
        );
      },
    );

    test('a trailing [videoid] is stripped from the uploader', () {
      expect(done[0].uploader, 'Rick Astley');
    });

    test('file stands in for filename, and artist for uploader', () {
      expect(done[1].filename, 'أغنية تجريبية من ساوند كلاود.sc-track-9.mp3');
      expect(done[1].uploader, 'Artist Name');
    });

    test(
      'a nanosecond timestamp, above 1e13, is converted to milliseconds',
      () {
        expect(done[1].timestamp?.year, 2026);
        expect(done[1].timestamp?.month, 9);
      },
    );

    test('a Facebook item: state=done means completed, an ISO datetime, and nothing invented', () {
      final fb = done[2];
      expect(fb.id, 'fb-reel-1');
      expect(fb.status, ItemStatus.completed);
      expect(fb.filename, isNull);
      expect(fb.thumbnail, isNull); // no ytimg for Facebook
      expect(fb.uploader, 'SomePage');
      expect(fb.timestamp?.toUtc().hour, 6);
    });

    test('entry.thumbnails takes the last entry, the highest quality', () {
      expect(done[3].thumbnail, 'https://i.vimeocdn.com/video/high.jpg');
    });
  });

  group('HistoryItem.fromJson — fixture: history_error_cookies', () {
    late List<HistoryItem> done;
    setUp(
      () => done = HistoryResponse.fromJson(
        loadFixture('history_error_cookies.json'),
      ).done,
    );

    test('a cookie or sign-in error means isPlatformBlocked', () {
      expect(done[0].status, ItemStatus.failed);
      expect(done[0].isPlatformBlocked, isTrue);
    });

    test('a "not a bot" error means isPlatformBlocked', () {
      expect(done[1].isPlatformBlocked, isTrue);
    });

    test('an ordinary failure: message stands in for error, and it is not a platform block', () {
      expect(done[2].status, ItemStatus.failed);
      expect(done[2].error, 'Unsupported URL');
      expect(done[2].isPlatformBlocked, isFalse);
    });
  });

  group('HistoryItem: the edges', () {
    test('with no id, a unique uuid for every call', () {
      final a = HistoryItem.fromJson({'url': 'https://x.com/a/status/1'});
      final b = HistoryItem.fromJson({'url': 'https://x.com/a/status/1'});
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(b.id));
    });

    test('a progress already within 0..1 is left as it is', () {
      final item = HistoryItem.fromJson({'url': 'u', 'progress': 0.7});
      expect(item.progress, 0.7);
    });

    test('no status and no error means unknown', () {
      final item = HistoryItem.fromJson({'url': 'u'});
      expect(item.status, ItemStatus.unknown);
      expect(item.hasError, isFalse);
    });

    test('an error text with no status means failed', () {
      final item = HistoryItem.fromJson({'url': 'u', 'error': 'boom'});
      expect(item.status, ItemStatus.failed);
    });
  });
}
