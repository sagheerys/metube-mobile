import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime(2026, 9, 1, 14, 30, 5);

  group('buildLocalFilename (§2.4)', () {
    test('عنوان عربي يبقى، الامتداد من اسم السيرفر', () {
      expect(
        buildLocalFilename('أنشودة جميلة', serverFilename: 'x.abc.mp3', now: at),
        'أنشودة جميلة_143005.mp3',
      );
    });

    test('المحارف غير الصالحة تُزال والمسافات تُدمج', () {
      expect(
        buildLocalFilename('a/b\\c:  d*e?"f"<g>|h', now: at),
        'abc defgh_143005.mp4',
      );
    });

    test('قص العنوان إلى 80 محرفاً', () {
      final name = buildLocalFilename('ط' * 200, now: at);
      expect(name.split('_').first.length, MTConstants.filenameTitleMaxLength);
    });

    test('عنوان كله محارف خاصة ⇒ video', () {
      expect(buildLocalFilename('***???', now: at), 'video_143005.mp4');
    });

    test('عنوان null ⇒ video بالامتداد الافتراضي', () {
      expect(buildLocalFilename(null, now: at), 'video_143005.mp4');
    });
  });

  group('extensionOf', () {
    test('امتداد صالح من اسم السيرفر', () {
      expect(extensionOf('أغنية.sc-9.webm'), 'webm');
      expect(extensionOf('a.M4A'), 'm4a');
    });

    test('غياب/فساد الامتداد ⇒ mp4', () {
      expect(extensionOf(null), 'mp4');
      expect(extensionOf('noext'), 'mp4');
      expect(extensionOf('عنوان.نقطة'), 'mp4');
      expect(extensionOf('a.'), 'mp4');
      expect(extensionOf('a.toolong7'), 'mp4');
    });
  });
}
