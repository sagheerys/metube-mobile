import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime(2026, 9, 1, 14, 30, 5);

  group('buildLocalFilename (§2.4)', () {
    test("an Arabic title survives, and the extension comes from the server's name", () {
      expect(
        buildLocalFilename(
          'أنشودة جميلة',
          serverFilename: 'x.abc.mp3',
          now: at,
        ),
        'أنشودة جميلة_143005.mp3',
      );
    });

    test('invalid characters are removed and runs of spaces collapse', () {
      expect(
        buildLocalFilename('a/b\\c:  d*e?"f"<g>|h', now: at),
        'abc defgh_143005.mp4',
      );
    });

    test('the title is cut to 80 characters', () {
      final name = buildLocalFilename('ط' * 200, now: at);
      expect(name.split('_').first.length, MTConstants.filenameTitleMaxLength);
    });

    test('a title of nothing but special characters becomes video', () {
      expect(buildLocalFilename('***???', now: at), 'video_143005.mp4');
    });

    test('a null title becomes video, with the default extension', () {
      expect(buildLocalFilename(null, now: at), 'video_143005.mp4');
    });
  });

  group('extensionOf', () {
    test("a valid extension from the server's name", () {
      expect(extensionOf('أغنية.sc-9.webm'), 'webm');
      expect(extensionOf('a.M4A'), 'm4a');
    });

    test('a missing or malformed extension becomes mp4', () {
      expect(extensionOf(null), 'mp4');
      expect(extensionOf('noext'), 'mp4');
      expect(extensionOf('عنوان.نقطة'), 'mp4');
      expect(extensionOf('a.'), 'mp4');
      expect(extensionOf('a.toolong7'), 'mp4');
    });
  });
}
