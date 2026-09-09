import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **ح-2 and خ-5**: the negative gaps that hid both defects, namely zero
/// negative matching tests for anything but YouTube, and zero tests for
/// direction marks inside Arabic text.
void main() {
  group('containment does not match the wrong item', () {
    test('a SoundCloud track does not match its own remix', () {
      expect(
        UrlKit.urlsMatch(
          'https://soundcloud.com/artist/track',
          'https://soundcloud.com/artist/track-remix',
        ),
        isFalse,
        reason: 'كان يُسحب الريمكس باسم الأصلي ثم يُحذف من السيرفر',
      );
    });

    test('different SoundCloud URLs by the same artist are not equal', () {
      expect(
        UrlKit.urlsMatch(
          'https://soundcloud.com/artist/song-one',
          'https://soundcloud.com/artist/song-one-live',
        ),
        isFalse,
      );
    });

    test('a private URL, a full path prefix, still matches', () {
      expect(
        UrlKit.urlsMatch(
          'https://soundcloud.com/artist/track',
          'https://soundcloud.com/artist/track/s-AbCd123',
        ),
        isTrue,
      );
    });

    test('a numeric id is not a prefix of a longer one', () {
      expect(
        UrlKit.urlsMatch(
          'https://vimeo.com/1234567890',
          'https://vimeo.com/12345678901',
        ),
        isFalse,
      );
    });

    test('an identical numeric id matches despite a different URL shape', () {
      expect(
        UrlKit.urlsMatch(
          'https://www.tiktok.com/@a/video/7301234567890123456',
          'https://m.tiktok.com/v/7301234567890123456.html',
        ),
        isTrue,
      );
    });

    test('two entirely different paths on the same host do not match', () {
      expect(
        UrlKit.urlsMatch(
          'https://vimeo.com/channels/staffpicks',
          'https://vimeo.com/chan',
        ),
        isFalse,
      );
    });
  });

  group('the direction marks in an Arabic share', () {
    test('RLM and LRM around the URL are trimmed', () {
      const wrapped = '\u200Fشاهد هذا \u200Ehttps://youtu.be/dQw4w9WgXcQ\u200F';
      expect(UrlKit.extractUrl(wrapped), 'https://youtu.be/dQw4w9WgXcQ');
    });

    test(
      'a zero-width space in the surrounding text does not contaminate the URL',
      () {
        const wrapped = 'رابط:\u200B https://soundcloud.com/a/b\u200B';
        expect(UrlKit.extractUrl(wrapped), 'https://soundcloud.com/a/b');
      },
    );

    test('extractAllUrls cleans them too', () {
      const text =
          '\u202Bالأول https://youtu.be/aaaaaaaaaaa\u200F والثاني '
          'https://youtu.be/bbbbbbbbbbb\u202C';
      expect(UrlKit.extractAllUrls(text), [
        'https://youtu.be/aaaaaaaaaaa',
        'https://youtu.be/bbbbbbbbbbb',
      ]);
    });

    test('a BOM at the start of the pasted text', () {
      expect(
        UrlKit.extractUrl('\uFEFFhttps://youtu.be/dQw4w9WgXcQ'),
        'https://youtu.be/dQw4w9WgXcQ',
      );
    });
  });
}
