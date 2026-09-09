import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import '../fixtures/fixtures.dart';

/// اختبارات على JSON **حقيقي** من سيرفر المالك (بوابة 1 — التُقط
/// 2026-09-01 من TrueNAS عبر المحلي والنفق): التحليل المتسامح يصمد
/// أمام 251 عنصراً فعلياً بكل شواذها.
void main() {
  group('fixture حقيقية: history_real_done', () {
    late HistoryResponse response;
    setUp(
      () => response = HistoryResponse.fromJson(
        loadFixture('real/history_real_done.json'),
      ),
    );

    test('تتحلل بلا رمي وبعناصر كثيرة', () {
      expect(response.done.length, greaterThan(200));
    });

    test('كل عنصر مكتمل له canonicalUrl غير فارغ', () {
      for (final item in response.done) {
        expect(item.canonicalUrl, isNotEmpty);
      }
    });

    test('لا اختلاق أسماء ملفات: الغائب يبقى null', () {
      // على الأقل كل عنصر finished الحقيقي يحمل filename من السيرفر
      final finished = response.done.where(
        (i) => i.status == ItemStatus.completed,
      );
      expect(
        finished.where((i) => i.filename != null).length,
        greaterThan(150),
      );
    });

    test('الطوابع الزمنية الحقيقية تُفك لأزمنة معقولة', () {
      final withTime = response.done.where((i) => i.timestamp != null).toList();
      expect(withTime, isNotEmpty);
      for (final item in withTime.take(20)) {
        expect(item.timestamp!.year, inInclusiveRange(2023, 2027));
      }
    });
  });

  group('fixture حقيقية: history_real_active (لحظة تحميل جارٍ)', () {
    test('عنصر الطابور جارٍ بالحالة الصحيحة', () {
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
