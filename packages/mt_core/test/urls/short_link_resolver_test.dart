import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('ShortLinkResolver', () {
    test('يتتبع سلسلة redirect حتى الوجهة', () async {
      final hops = {
        'https://vt.tiktok.com/ZS8abc/': 'https://vm.tiktok.com/ZS8abc/redir',
        'https://vm.tiktok.com/ZS8abc/redir':
            'https://www.tiktok.com/@user/video/7301234567890123456',
      };
      final resolver = ShortLinkResolver(
        redirectStep: (url) async => hops[url],
      );
      expect(
        await resolver.resolve('https://vt.tiktok.com/ZS8abc/'),
        'https://www.tiktok.com/@user/video/7301234567890123456',
      );
    });

    test('Location نسبي يُحل على الرابط الحالي', () async {
      final resolver = ShortLinkResolver(
        redirectStep: (url) async =>
            url == 'https://fb.watch/abc/' ? '/watch/?v=9876543210987' : null,
      );
      expect(
        await resolver.resolve('https://fb.watch/abc/'),
        'https://fb.watch/watch/?v=9876543210987',
      );
    });

    test('منع الهبوط HTTPS→HTTP ⇒ يعيد الأصلي', () async {
      final resolver = ShortLinkResolver(
        redirectStep: (url) async =>
            url == 'https://on.soundcloud.com/x' ? 'http://evil.com/t' : null,
      );
      expect(
        await resolver.resolve('https://on.soundcloud.com/x'),
        'https://on.soundcloud.com/x',
      );
    });

    test('غير القصير يمر دون أي طلب', () async {
      var calls = 0;
      final resolver = ShortLinkResolver(
        redirectStep: (url) async {
          calls++;
          return null;
        },
      );
      const full = 'https://www.tiktok.com/@user/video/1';
      expect(await resolver.resolve(full), full);
      expect(calls, 0);
    });

    test('فشل الجلب ⇒ يعيد الأصلي كما هو', () async {
      final resolver = ShortLinkResolver(
        redirectStep: (url) async => throw Exception('network down'),
      );
      expect(
        await resolver.resolve('https://vm.tiktok.com/x/'),
        'https://vm.tiktok.com/x/',
      );
    });

    test('حلقة redirect لا نهائية تتوقف عند حد القفزات', () async {
      var calls = 0;
      final resolver = ShortLinkResolver(
        redirectStep: (url) async {
          calls++;
          return 'https://vm.tiktok.com/loop/';
        },
      );
      await resolver.resolve('https://vm.tiktok.com/loop/');
      expect(calls, MTConstants.maxRedirectHops);
    });
  });

  /// **Field report 2026-09-08: a whole album downloaded with no selection
  /// screen.**
  ///
  /// SoundCloud's share button gives `on.soundcloud.com/…`, which contains
  /// no `/sets/`, so `PlaylistDetector` sees a single clip. It passed to
  /// the server, yt-dlp expanded it into **20 clips** and all of them
  /// downloaded, while the app knew of one task. The decision has to be
  /// made on the final URL.
  group('resolveForRouting — القرار على الرابط النهائي', () {
    const short = 'https://on.soundcloud.com/AbCdEf';
    const album = 'https://soundcloud.com/artist/sets/my-album';

    test('القصير وحده يبدو مفرداً، والمحلول يُكشف ألبوماً', () async {
      expect(
        PlaylistDetector.isPlaylist(short),
        isFalse,
        reason: 'هذا هو الفخ نفسه: لا `/sets/` في الرابط القصير',
      );

      final resolver = ShortLinkResolver(
        redirectStep: (url) async => url == short ? album : null,
      );
      final resolved = await resolver.resolveForRouting(short);

      expect(resolved, album);
      expect(
        PlaylistDetector.isPlaylist(resolved),
        isTrue,
        reason: 'وبعد الحل يذهب إلى شاشة الاختيار لا إلى السيرفر',
      );
    });

    test('رابط عادي لا ينتظر شبكة إطلاقاً', () async {
      var touched = false;
      final resolver = ShortLinkResolver(
        redirectStep: (url) async {
          touched = true;
          return null;
        },
      );
      const plain = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      expect(await resolver.resolveForRouting(plain), plain);
      expect(touched, isFalse, reason: 'needsResolution تحسمها قبل الشبكة');
    });

    test('شبكة بطيئة ⇒ يُمضى بالرابط كما هو بلا تجميد', () async {
      final resolver = ShortLinkResolver(
        redirectStep: (url) async {
          await Future<void>.delayed(const Duration(minutes: 1));
          return album;
        },
      );
      final started = DateTime.now();
      final out = await resolver.resolveForRouting(short);
      expect(out, short);
      expect(
        DateTime.now().difference(started),
        lessThan(
          MTConstants.routingResolveTimeout + const Duration(seconds: 3),
        ),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
