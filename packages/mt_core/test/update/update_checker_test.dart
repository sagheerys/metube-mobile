import 'dart:convert';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// ردّ GitHub على `releases/latest` بالحقول التي يقرؤها المحلّل فعلاً.
String release({
  String tag = 'v2.1.0',
  bool draft = false,
  bool prerelease = false,
  List<Map<String, Object?>>? assets,
}) =>
    json.encode({
      'tag_name': tag,
      'name': 'MeTube Mobile $tag',
      'body': 'إصلاحات وتحسينات',
      'draft': draft,
      'prerelease': prerelease,
      'html_url': 'https://github.com/sagheerys/metube-mobile/releases/$tag',
      'published_at': '2026-09-20T10:00:00Z',
      'assets': assets ??
          [
            {
              'name': 'MeTube-Lite-$tag.apk',
              'browser_download_url': 'https://x/lite.apk',
              'size': 21000000,
            },
            {
              'name': 'MeTube-Super-$tag.apk',
              'browser_download_url': 'https://x/super.apk',
              'size': 24000000,
            },
          ],
    });

UpdateChecker checkerOf(String body, {String marker = 'super'}) =>
    UpdateChecker(fetch: (_) async => body, assetMarker: marker);

void main() {
  group('اختيار الأصل', () {
    test('**الحارس**: كل تطبيق يأخذ ملفه لا ملف أخيه', () async {
      // الإصدار الواحد يحمل APK التطبيقين؛ بلا مطابقة العلامة يثبّت
      // مالك Lite نسخة Super (أول أصل في القائمة).
      final superRelease =
          await checkerOf(release()).check(currentVersion: '2.0.0');
      expect(superRelease!.apkUrl, 'https://x/super.apk');
      expect(superRelease.apkSize, 24000000);

      final liteRelease = await checkerOf(release(), marker: 'lite')
          .check(currentVersion: '2.0.0');
      expect(liteRelease!.apkUrl, 'https://x/lite.apk');
    });

    test('إصدار بلا APK لهذا التطبيق = لا تحديث', () async {
      final body = release(assets: [
        {
          'name': 'MeTube-Lite-v2.1.0.apk',
          'browser_download_url': 'https://x/lite.apk',
          'size': 1,
        }
      ]);
      expect(await checkerOf(body).check(currentVersion: '2.0.0'), isNull);
    });

    test('يتجاهل المرفقات غير التنفيذية', () async {
      final body = release(assets: [
        {
          'name': 'metube-super-sources.zip',
          'browser_download_url': 'https://x/src.zip',
          'size': 5,
        },
        {
          'name': 'MeTube-Super-v2.1.0.apk',
          'browser_download_url': 'https://x/super.apk',
          'size': 7,
        },
      ]);
      final r = await checkerOf(body).check(currentVersion: '2.0.0');
      expect(r!.apkUrl, 'https://x/super.apk');
    });
  });

  group('سياسة العرض', () {
    test('لا يعرض ما ليس أحدث', () async {
      final c = checkerOf(release(tag: 'v2.0.0'));
      expect(await c.check(currentVersion: '2.0.0'), isNull);
      expect(await c.check(currentVersion: '2.1.0'), isNull);
    });

    test('المسودّة والتجريبي مرفوضان', () async {
      expect(await checkerOf(release(draft: true)).check(currentVersion: '2.0.0'),
          isNull);
      expect(
          await checkerOf(release(prerelease: true))
              .check(currentVersion: '2.0.0'),
          isNull);
    });

    test('«تخطّي هذا الإصدار» يكتم الحالي ويعود مع التالي', () async {
      final c = checkerOf(release());
      expect(
          await c.check(currentVersion: '2.0.0', skippedVersion: '2.1.0'),
          isNull);
      // إصدار أحدث من المتخطّى يظهر — التخطّي ليس تعطيلاً دائماً.
      final next = checkerOf(release(tag: 'v2.2.0'));
      final r =
          await next.check(currentVersion: '2.0.0', skippedVersion: '2.1.0');
      expect(r!.tag, 'v2.2.0');
    });

    test('إصدار محلي غير مقروء = لا فحص', () async {
      expect(await checkerOf(release()).check(currentVersion: 'dev'), isNull);
    });
  });

  group('فاشل-آمن', () {
    test('**الحارس**: أي عطل شبكة يعيد null ولا يرمي', () async {
      // المستودع خاصٌّ الآن ⇒ GitHub يردّ 404 عند كل فحص تلقائي.
      // رميُ استثناء هنا يعني رسالة خطأ في وجه المستخدم عند كل إقلاع.
      final c = UpdateChecker(
          fetch: (_) async => throw Exception('404'), assetMarker: 'super');
      expect(await c.check(currentVersion: '2.0.0'), isNull);
    });

    test('**الحارس**: الفحص اليدوي يميّز «لا جديد» عن «تعذّر الوصول»', () async {
      // في `check` النتيجتان `null` واحدة، فلو بُني الزر اليدوي عليها
      // قال «أنت على أحدث إصدار» والشبكة مقطوعة أصلاً.
      final broken = UpdateChecker(
          fetch: (_) async => throw Exception('offline'), assetMarker: 'super');
      await expectLater(broken.checkOrThrow(currentVersion: '2.0.0'), throwsA(anything));

      final same = checkerOf(release(tag: 'v2.0.0'));
      expect(await same.checkOrThrow(currentVersion: '2.0.0'), isNull);
    });

    test('JSON مشوّه أو غير متوقّع يعيد null', () async {
      for (final body in ['', 'not json', '[]', '{}', '{"tag_name":123}']) {
        expect(await checkerOf(body).check(currentVersion: '2.0.0'), isNull,
            reason: 'الجسم «$body»');
      }
    });
  });

  group('isDue', () {
    final now = DateTime(2026, 9, 20, 12);

    test('يفحص أول مرة ثم يحترم الإيقاع', () {
      expect(UpdateChecker.isDue(null, now), isTrue);
      expect(UpdateChecker.isDue(now.subtract(const Duration(hours: 1)), now),
          isFalse);
      expect(UpdateChecker.isDue(now.subtract(const Duration(hours: 13)), now),
          isTrue);
    });

    test('**الحارس**: ساعة راجعة للوراء لا تجمّد الفحص للأبد', () {
      // تغيير المنطقة أو مزامنة NTP قد يجعل آخر فحص «في المستقبل»؛
      // بلا هذا الفرع يبقى الفرق سالباً فلا يحين الفحص أبداً.
      final future = now.add(const Duration(days: 400));
      expect(UpdateChecker.isDue(future, now), isTrue);
    });
  });
}
