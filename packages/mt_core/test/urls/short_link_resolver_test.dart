import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  /// **Reddit: the defect, and why resolution is the fix** (field report
  /// 2026-09-20).
  ///
  /// The report: a Reddit link downloads on the server but the app's
  /// counter never moves — Lite never pulls the file and never cleans the
  /// server, and Super shows a stuck card beside a clip already sitting in
  /// the library. The cause is not the download: MeTube files an item under
  /// the URL **yt-dlp ended at** and keys every list by it, so a task that
  /// asked for the short link is polling for a URL that does not exist on
  /// the server.
  ///
  /// The hops below are the ones measured against reddit.com on that day,
  /// not invented.
  group('Reddit share links', () {
    const post =
        'https://www.reddit.com/r/reacher/comments/1w64qio/reacher_matters/';

    test('the app link — the one the share button produces — is followed to '
        'the post, keeping the tail the redirect adds', () async {
      const shared = 'https://www.reddit.com/r/reacher/s/AbCdEfGh12';
      // The real Location carries share_id and utm_*; a stored URL wearing
      // that tail is the fingerprint of a link that arrived this way.
      const target =
          '$post?share_id=OaIBOBGNVYFeEkmaAcJE2'
          '&utm_medium=android_app&utm_source=share';
      final resolver = ShortLinkResolver(
        redirectStep: (url) async => url == shared ? target : null,
      );
      expect(await resolver.resolve(shared), target);
    });

    test('redd.it lands where the server files it', () async {
      final resolver = ShortLinkResolver(
        redirectStep: (url) async => url == 'https://redd.it/1w64qio'
            ? 'https://www.reddit.com/comments/1w64qio'
            : null,
      );
      // Exactly the pair measured on a real server: sent on the left,
      // filed on the right.
      expect(
        await resolver.resolve('https://redd.it/1w64qio'),
        'https://www.reddit.com/comments/1w64qio',
      );
    });

    test('v.redd.it takes two hops, and both are followed', () async {
      const hops = {
        'https://v.redd.it/52oky0lgjanh1':
            'https://www.reddit.com/video/52oky0lgjanh1',
        'https://www.reddit.com/video/52oky0lgjanh1': post,
      };
      final resolver = ShortLinkResolver(
        redirectStep: (url) async => hops[url],
      );
      expect(await resolver.resolve('https://v.redd.it/52oky0lgjanh1'), post);
    });

    test('and the point of all three: unresolved, the pair does not match, '
        'so the task polls for something the server has never heard of', () {
      for (final short in [
        'https://redd.it/1w64qio',
        'https://v.redd.it/52oky0lgjanh1',
        'https://www.reddit.com/r/reacher/s/AbCdEfGh12',
      ]) {
        expect(
          UrlKit.urlsMatch('https://www.reddit.com/comments/1w64qio', short),
          isFalse,
          reason:
              'لو طابقها المطابِق لكان التخمين هو ما ينقذنا، لا الحل: $short',
        );
      }
      // Resolved, it is the same string, which is the only match worth
      // having.
      expect(
        UrlKit.urlsMatch(
          'https://www.reddit.com/comments/1w64qio',
          'https://www.reddit.com/comments/1w64qio',
        ),
        isTrue,
      );
    });
  });

  /// **Vimeo: the same defect, on a link nobody would call "short"** (field
  /// report 2026-09-20, with cookies working and the clip downloaded).
  ///
  /// The link pasted was the address Vimeo shows on an author's page. The
  /// server filed the clip under the number that address redirects to, so
  /// the card sat at 0% beside the finished clip in the library — **and the
  /// arrival notice announced the user's own download back to them**,
  /// because a task
  /// is marked as ours by the canonical URL the poll captures, and the poll
  /// never captured one.
  group('Vimeo author-page links', () {
    test('the link is followed to the number the server files it under', () {
      const shown = 'https://vimeo.com/hugodesousa/bestfriendswiththedevil';
      const filed = 'https://vimeo.com/1225400313';

      expect(UrlKit.needsResolution(shown), isTrue);
      expect(
        UrlKit.urlsMatch(filed, shown),
        isFalse,
        reason: 'هذا الزوج بعينه هو ما رآه التطبيق فعلق',
      );
      // Resolved, the two are one string.
      expect(UrlKit.urlsMatch(filed, filed), isTrue);
    });

    test('a relative Location is what Vimeo actually sends, and it resolves '
        'against the host rather than being pasted on', () async {
      final resolver = ShortLinkResolver(
        // Measured: `location: /1225400313`, with no scheme and no host.
        redirectStep: (url) async =>
            url.contains('hugodesousa') ? '/1225400313' : null,
      );
      expect(
        await resolver.resolve(
          'https://vimeo.com/hugodesousa/bestfriendswiththedevil',
        ),
        'https://vimeo.com/1225400313',
      );
    });
  });

  group('ShortLinkResolver', () {
    test('it follows a chain of redirects to the destination', () async {
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

    test('a relative Location resolves against the current URL', () async {
      final resolver = ShortLinkResolver(
        redirectStep: (url) async =>
            url == 'https://fb.watch/abc/' ? '/watch/?v=9876543210987' : null,
      );
      expect(
        await resolver.resolve('https://fb.watch/abc/'),
        'https://fb.watch/watch/?v=9876543210987',
      );
    });

    test(
      'an HTTPS to HTTP downgrade is refused, returning the original',
      () async {
        final resolver = ShortLinkResolver(
          redirectStep: (url) async =>
              url == 'https://on.soundcloud.com/x' ? 'http://evil.com/t' : null,
        );
        expect(
          await resolver.resolve('https://on.soundcloud.com/x'),
          'https://on.soundcloud.com/x',
        );
      },
    );

    test(
      'anything that is not a short link passes with no request at all',
      () async {
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
      },
    );

    test('a failed fetch returns the original untouched', () async {
      final resolver = ShortLinkResolver(
        redirectStep: (url) async => throw Exception('network down'),
      );
      expect(
        await resolver.resolve('https://vm.tiktok.com/x/'),
        'https://vm.tiktok.com/x/',
      );
    });

    test('an endless redirect loop stops at the hop limit', () async {
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
  group('resolveForRouting: the decision is made on the final URL', () {
    const short = 'https://on.soundcloud.com/AbCdEf';
    const album = 'https://soundcloud.com/artist/sets/my-album';

    test('the short link alone looks single; resolved, it turns out to be an album', () async {
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

    test('an ordinary URL waits for no network at all', () async {
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

    test(
      'a slow network passes the URL through unchanged rather than freezing',
      () async {
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
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
