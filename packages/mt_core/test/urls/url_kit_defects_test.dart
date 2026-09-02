import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **ح-2 وخ-5** — الثغرات السلبية التي أخفت العطلين: صفر اختبار مطابقة
/// سلبي لغير YouTube، وصفر اختبار لعلامات الاتجاه في النص العربي.
void main() {
  group('ح-2 — الاحتواء لا يطابق العنصر الخطأ', () {
    test('مقطع SoundCloud لا يطابق ريمكسه', () {
      expect(
        UrlKit.urlsMatch('https://soundcloud.com/artist/track',
            'https://soundcloud.com/artist/track-remix'),
        isFalse,
        reason: 'كان يُسحب الريمكس باسم الأصلي ثم يُحذف من السيرفر',
      );
    });

    test('روابط SoundCloud مختلفة لنفس الفنان لا تتساوى', () {
      expect(
        UrlKit.urlsMatch('https://soundcloud.com/artist/song-one',
            'https://soundcloud.com/artist/song-one-live'),
        isFalse,
      );
    });

    test('الرابط الخاص (بادئة مسار كاملة) يبقى مطابقاً', () {
      expect(
        UrlKit.urlsMatch('https://soundcloud.com/artist/track',
            'https://soundcloud.com/artist/track/s-AbCd123'),
        isTrue,
      );
    });

    test('معرف رقمي ليس بادئة معرف أطول', () {
      expect(
        UrlKit.urlsMatch('https://vimeo.com/1234567890',
            'https://vimeo.com/12345678901'),
        isFalse,
      );
    });

    test('معرف رقمي متطابق يطابق رغم اختلاف شكل الرابط', () {
      expect(
        UrlKit.urlsMatch('https://www.tiktok.com/@a/video/7301234567890123456',
            'https://m.tiktok.com/v/7301234567890123456.html'),
        isTrue,
      );
    });

    test('مساران مختلفان تماماً على نفس المضيف لا يتطابقان', () {
      expect(
        UrlKit.urlsMatch(
            'https://vimeo.com/channels/staffpicks', 'https://vimeo.com/chan'),
        isFalse,
      );
    });
  });

  group('خ-5 — علامات الاتجاه في المشاركة العربية', () {
    test('RLM/LRM حول الرابط تُقصّ', () {
      const wrapped = '\u200Fشاهد هذا \u200Ehttps://youtu.be/dQw4w9WgXcQ\u200F';
      expect(UrlKit.extractUrl(wrapped), 'https://youtu.be/dQw4w9WgXcQ');
    });

    test('المسافة الصفرية داخل النص المحيط لا تلوث الرابط', () {
      const wrapped = 'رابط:\u200B https://soundcloud.com/a/b\u200B';
      expect(UrlKit.extractUrl(wrapped), 'https://soundcloud.com/a/b');
    });

    test('extractAllUrls تنظف كذلك', () {
      const text =
          '\u202Bالأول https://youtu.be/aaaaaaaaaaa\u200F والثاني '
          'https://youtu.be/bbbbbbbbbbb\u202C';
      expect(UrlKit.extractAllUrls(text), [
        'https://youtu.be/aaaaaaaaaaa',
        'https://youtu.be/bbbbbbbbbbb',
      ]);
    });

    test('BOM في بداية النص الملصق', () {
      expect(UrlKit.extractUrl('\uFEFFhttps://youtu.be/dQw4w9WgXcQ'),
          'https://youtu.be/dQw4w9WgXcQ');
    });
  });
}
