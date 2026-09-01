import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import '../fixtures/fixtures.dart';

void main() {
  group('HistoryItem.fromJson — fixture: history_active', () {
    late HistoryResponse response;
    setUp(() => response = HistoryResponse.fromJson(loadFixture('history_active.json')));

    test('percent > 1 يُقسم على 100', () {
      expect(response.queue.first.progress, closeTo(0.453, 0.0001));
    });

    test('downloading ⇒ inProgress', () {
      expect(response.queue.first.status, ItemStatus.inProgress);
      expect(response.queue.first.isDownloading, isTrue);
    });

    test('الفخ: filename الغائب يبقى null — لا يُخلَّق من العنوان', () {
      expect(response.queue.first.filename, isNull);
    });

    test('state=preparing (مرادف) ⇒ inProgress', () {
      expect(response.queue[1].status, ItemStatus.inProgress);
    });

    test('pending: _id بديل id، وname بديل title', () {
      final item = response.pending.single;
      expect(item.id, 'pend-1');
      expect(item.title, 'قائمة الانتظار — مقطع معلق');
      expect(item.status, ItemStatus.inProgress);
    });

    test('لا ytimg لغير YouTube: عنصر SoundCloud بلا صورة ⇒ null', () {
      expect(response.queue[1].thumbnail, isNull);
    });
  });

  group('HistoryItem.fromJson — fixture: history_done', () {
    late List<HistoryItem> done;
    setUp(() =>
        done = HistoryResponse.fromJson(loadFixture('history_done.json')).done);

    test('finished ⇒ completed مع filename حقيقي من السيرفر', () {
      expect(done[0].status, ItemStatus.completed);
      expect(done[0].filename, endsWith('.dQw4w9WgXcQ.mp4'));
    });

    test('YouTube بلا حقل صورة ⇒ اشتقاق i.ytimg من المعرف', () {
      expect(done[0].thumbnail,
          'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
    });

    test('لاحقة [videoid] تُزال من الرافع', () {
      expect(done[0].uploader, 'Rick Astley');
    });

    test('file بديل filename، وartist بديل uploader', () {
      expect(done[1].filename, 'أغنية تجريبية من ساوند كلاود.sc-track-9.mp3');
      expect(done[1].uploader, 'Artist Name');
    });

    test('timestamp نانوثانية (>1e13) يُحوَّل ميلي ثانية', () {
      expect(done[1].timestamp?.year, 2026);
      expect(done[1].timestamp?.month, 9);
    });

    test('عنصر Facebook: state=done ⇒ completed، datetime ISO، بلا اختلاق', () {
      final fb = done[2];
      expect(fb.id, 'fb-reel-1');
      expect(fb.status, ItemStatus.completed);
      expect(fb.filename, isNull);
      expect(fb.thumbnail, isNull); // لا ytimg لفيسبوك
      expect(fb.uploader, 'SomePage');
      expect(fb.timestamp?.toUtc().hour, 6);
    });

    test('entry.thumbnails ⇒ آخر عنصر (الأعلى جودة)', () {
      expect(done[3].thumbnail, 'https://i.vimeocdn.com/video/high.jpg');
    });
  });

  group('HistoryItem.fromJson — fixture: history_error_cookies', () {
    late List<HistoryItem> done;
    setUp(() => done = HistoryResponse.fromJson(
        loadFixture('history_error_cookies.json')).done);

    test('خطأ كوكيز/تسجيل دخول ⇒ isPlatformBlocked', () {
      expect(done[0].status, ItemStatus.failed);
      expect(done[0].isPlatformBlocked, isTrue);
    });

    test('خطأ "not a bot" ⇒ isPlatformBlocked', () {
      expect(done[1].isPlatformBlocked, isTrue);
    });

    test('فشل عادي: message بديل error، ليس محظور منصة', () {
      expect(done[2].status, ItemStatus.failed);
      expect(done[2].error, 'Unsupported URL');
      expect(done[2].isPlatformBlocked, isFalse);
    });
  });

  group('HistoryItem — حواف', () {
    test('بلا id ⇒ uuid فريد لكل استدعاء', () {
      final a = HistoryItem.fromJson({'url': 'https://x.com/a/status/1'});
      final b = HistoryItem.fromJson({'url': 'https://x.com/a/status/1'});
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(b.id));
    });

    test('progress ضمن 0..1 يبقى كما هو', () {
      final item = HistoryItem.fromJson({'url': 'u', 'progress': 0.7});
      expect(item.progress, 0.7);
    });

    test('بلا حالة وبلا خطأ ⇒ unknown', () {
      final item = HistoryItem.fromJson({'url': 'u'});
      expect(item.status, ItemStatus.unknown);
      expect(item.hasError, isFalse);
    });

    test('خطأ نصي بلا status ⇒ failed', () {
      final item = HistoryItem.fromJson({'url': 'u', 'error': 'boom'});
      expect(item.status, ItemStatus.failed);
    });
  });
}
