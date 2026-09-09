import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('UrlKit.extractUrl — سلّم م-4', () {
    test('رابط نقي يعود كما هو', () {
      expect(
        UrlKit.extractUrl('https://youtu.be/dQw4w9WgXcQ'),
        'https://youtu.be/dQw4w9WgXcQ',
      );
    });

    test('جملة مشاركة SoundCloud عربية ملفوفة حول الرابط', () {
      const share =
          'استمع إلى أغنيتي عبر فنان #SoundCloud '
          'https://on.soundcloud.com/AbCd123';
      expect(UrlKit.extractUrl(share), 'https://on.soundcloud.com/AbCd123');
    });

    test('رابط متبوع بنص ⇒ يقص عند أول فراغ', () {
      expect(
        UrlKit.extractUrl('https://vimeo.com/76979871 شاهد هذا'),
        'https://vimeo.com/76979871',
      );
    });

    test('تنظيف الترقيم الزائد بالنهاية', () {
      expect(
        UrlKit.extractUrl('جرب (https://www.reddit.com/r/videos/abc).'),
        'https://www.reddit.com/r/videos/abc',
      );
    });

    test('لا رابط ⇒ يعيد المدخل ليكشفه التحقق', () {
      expect(UrlKit.extractUrl('مجرد نص'), 'مجرد نص');
    });

    test('extractAllUrls لمشاركة عدة روابط (م-3)', () {
      const text =
          'https://youtu.be/aaaaaaaaaaa و https://youtu.be/bbbbbbbbbbb';
      expect(UrlKit.extractAllUrls(text), hasLength(2));
    });
  });

  group('UrlKit.youtubeVideoId', () {
    const id = 'dQw4w9WgXcQ';
    for (final url in [
      'https://www.youtube.com/watch?v=$id',
      'https://m.youtube.com/watch?v=$id&t=10s',
      'https://youtube.com/shorts/$id',
      'https://www.youtube.com/live/$id',
      'https://youtu.be/$id',
      'https://www.youtube.com/embed/$id',
      'https://www.youtube.com/watch?list=PLx&v=$id',
    ]) {
      test(url, () => expect(UrlKit.youtubeVideoId(url), id));
    }

    test('غير يوتيوب ⇒ null حتى مع v= في الاستعلام', () {
      expect(UrlKit.youtubeVideoId('https://example.com/watch?v=$id'), isNull);
      expect(
        UrlKit.youtubeVideoId('https://www.tiktok.com/@u/video/123'),
        isNull,
      );
    });
  });

  group('UrlKit.urlsMatch — السلّم الضبابي', () {
    test('حرفي', () {
      expect(UrlKit.urlsMatch('https://a.com/x', 'https://a.com/x'), isTrue);
    });

    test('youtu.be ⇄ watch (القنونة)', () {
      expect(
        UrlKit.urlsMatch(
          'https://youtu.be/dQw4w9WgXcQ',
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        isTrue,
      );
    });

    test('shorts ⇄ watch', () {
      expect(
        UrlKit.urlsMatch(
          'https://youtube.com/shorts/dQw4w9WgXcQ',
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        isTrue,
      );
    });

    test('معرف رقمي ≥10 (TikTok/FB)', () {
      expect(
        UrlKit.urlsMatch(
          'https://www.tiktok.com/@user/video/7301234567890123456',
          'https://m.tiktok.com/v/7301234567890123456.html',
        ),
        isTrue,
      );
    });

    test('تطبيع www/m والاستعلام', () {
      expect(
        UrlKit.urlsMatch(
          'https://www.soundcloud.com/artist/track?p=1',
          'http://m.soundcloud.com/artist/track/',
        ),
        isTrue,
      );
    });

    test('لا تطابق بين فيديوهين مختلفين', () {
      expect(
        UrlKit.urlsMatch(
          'https://youtu.be/aaaaaaaaaaa',
          'https://youtu.be/bbbbbbbbbbb',
        ),
        isFalse,
      );
    });

    test('انحدار السيرفر الحقيقي: رابطا watch بمعرفين مختلفين لا يتساويان '
        'عبر التطبيع (كاد يحذف عنصراً بريئاً)', () {
      expect(
        UrlKit.urlsMatch(
          'https://www.youtube.com/watch?v=jNQXAC9IVRw',
          'https://www.youtube.com/watch?v=Z1qxr2b0-VA',
        ),
        isFalse,
      );
      // And a watch URL does not match a YouTube URL with no id.
      expect(
        UrlKit.urlsMatch(
          'https://www.youtube.com/watch?v=jNQXAC9IVRw',
          'https://www.youtube.com/playlist?list=PLx',
        ),
        isFalse,
      );
    });

    test('فارغ ⇒ false', () {
      expect(UrlKit.urlsMatch('', 'https://a.com'), isFalse);
    });
  });

  group('UrlKit.isSafeServerFilename — حارس المسار', () {
    test('اسم عربي بمسافات صالح', () {
      expect(UrlKit.isSafeServerFilename('أغنية جميلة.dQw4.mp3'), isTrue);
    });

    // **`x..y` is deliberately accepted now (field report 2026-09-03).**
    // yt-dlp truncates long titles with an ellipsis, so the old
    // `contains('..')` condition rejected legitimate files the server
    // genuinely serves (measured: HTTP 206). Traversal needs a path
    // separator, which is rejected below.
    for (final good in ['x..y', 'مدر... [2077436096300945409].mp4', 'a....b']) {
      test('يقبل "$good"', () {
        expect(UrlKit.isSafeServerFilename(good), isTrue);
      });
    }

    for (final bad in [
      '',
      '.',
      '..',
      '../etc/passwd',
      'a/b.mp4',
      r'a\b.mp4',
      'a\u0000b.mp4',
    ]) {
      test('يرفض "$bad"', () {
        expect(UrlKit.isSafeServerFilename(bad), isFalse);
      });
    }
  });

  group('UrlKit.needsResolution', () {
    for (final short in [
      'https://vt.tiktok.com/ZS8abc/',
      'https://vm.tiktok.com/ZS8abc/',
      'https://fb.watch/abc123/',
      'https://www.facebook.com/share/v/abc/',
      'https://on.soundcloud.com/AbCd',
    ]) {
      test('قصير: $short', () => expect(UrlKit.needsResolution(short), isTrue));
    }

    test('الكامل لا يحتاج حلاً', () {
      expect(
        UrlKit.needsResolution('https://www.tiktok.com/@u/video/1'),
        isFalse,
      );
      expect(
        UrlKit.needsResolution('https://www.facebook.com/reel/123'),
        isFalse,
      );
    });
  });

  group('UrlKit.longestNumericId', () {
    test('يختار الأطول من المسار', () {
      expect(
        UrlKit.longestNumericId(
          'https://www.facebook.com/12345/videos/9876543210987',
        ),
        '9876543210987',
      );
    });

    test('أقل من 10 خانات ⇒ فارغ', () {
      expect(UrlKit.longestNumericId('https://vimeo.com/123456'), '');
    });
  });

  /// **Defect found 2026-09-08: colliding Facebook URLs.**
  ///
  /// Facebook puts the id in the query rather than the path, so
  /// `longestNumericId` returned empty for all of its links and matching
  /// fell through to the normalisation rank. Normalisation strips the
  /// query, so every `watch` URL collapsed to `facebook.com/watch`. The
  /// measured effect on a real device: one item made available offline gave
  /// its file to **every** Facebook item, so the fourth one opened the
  /// first one's clip in the external player. Worse, the same function
  /// matches `/history` in Lite, which means pulling an innocent file **and
  /// then deleting the original from the server**.
  group('urlsMatch — الهوية في الاستعلام (فيسبوك)', () {
    const a = 'https://m.facebook.com/watch/?v=1619243166301797&_rdr';
    const b = 'https://m.facebook.com/watch/?v=2657266731405287&_rdr';

    test('مقطعان مختلفان لا يتطابقان', () {
      expect(UrlKit.urlsMatch(a, b), isFalse);
      expect(UrlKit.urlsMatch(b, a), isFalse, reason: 'والعكس كذلك');
    });

    test('المعرف يُقرأ من الاستعلام لا المسار وحده', () {
      expect(UrlKit.longestNumericId(a), '1619243166301797');
    });

    test('نفس المقطع بصيغتين ما زال يتطابق', () {
      expect(
        UrlKit.urlsMatch(
          a,
          'https://www.facebook.com/watch/?v=1619243166301797&fbclid=x',
        ),
        isTrue,
        reason: 'المعرف الرقمي مرجع قبل رتبة الاستعلام',
      );
    });

    test('الرابط نفسه حرفياً يتطابق', () {
      expect(UrlKit.urlsMatch(a, a), isTrue);
    });

    /// The general guard: it is not limited to Facebook or to numeric ids.
    test('استعلامان مختلفان على نفس المسار ⇒ لا تطابق', () {
      expect(
        UrlKit.urlsMatch(
          'https://site.com/watch?id=abc',
          'https://site.com/watch?id=def',
        ),
        isFalse,
      );
    });

    test('استعلام في طرف واحد لا يمنع المطابقة', () {
      expect(
        UrlKit.urlsMatch(
          'https://vimeo.com/1234567890',
          'https://vimeo.com/1234567890?share=1',
        ),
        isTrue,
      );
    });
  });
}
