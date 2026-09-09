import 'dart:convert';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('SoundCloudResolver — معزول فشل-آمن (§4)', () {
    test('trackArtwork عبر oEmbed مع التكبير t500x500', () async {
      final resolver = SoundCloudResolver(
        httpGet: (uri) async {
          expect(uri.host, 'soundcloud.com');
          expect(uri.path, '/oembed');
          expect(uri.queryParameters['url'], contains('soundcloud.com'));
          return json.encode({
            'thumbnail_url': 'https://i1.sndcdn.com/artworks-abc-large.jpg',
          });
        },
      );
      expect(
        await resolver.trackArtwork('https://soundcloud.com/a/t'),
        'https://i1.sndcdn.com/artworks-abc-t500x500.jpg',
      );
    });

    test(
      'resolveSet يحلل window.__sc_hydration من HTML حقيقي البنية',
      () async {
        final hydration = json.encode([
          {'hydratable': 'anonymousId', 'data': 'x'},
          {
            'hydratable': 'playlist',
            'data': {
              'title': 'قائمة تجريبية',
              'artwork_url': 'https://i1.sndcdn.com/artworks-cover-large.jpg',
              'tracks': [
                {
                  'id': 111,
                  'title': 'مقطع ١',
                  'duration': 185000,
                  'permalink_url': 'https://soundcloud.com/a/t1',
                  'artwork_url': 'https://i1.sndcdn.com/artworks-1-large.jpg',
                },
                {'id': 222}, // an incomplete item (a stub), skipped
                {
                  'id': 333,
                  'title': 'مقطع ٢',
                  'duration': 60000,
                  'permalink_url': 'https://soundcloud.com/a/t2',
                },
              ],
            },
          },
        ]);
        final html =
            '<html><script>window.__sc_hydration = $hydration;'
            '</script></html>';
        final resolver = SoundCloudResolver(httpGet: (_) async => html);
        final preview = (await resolver.resolveSet(
          'https://soundcloud.com/a/sets/s',
        ))!;

        expect(preview.kind, PlaylistKind.soundcloud);
        expect(preview.title, 'قائمة تجريبية');
        expect(preview.coverUrl, contains('t500x500'));
        expect(preview.tracks, hasLength(2));
        expect(preview.tracks.first.duration, const Duration(seconds: 185));
        expect(preview.totalDuration, const Duration(seconds: 245));
      },
    );

    test('فشل الشبكة أو HTML بلا hydration ⇒ null بلا رمي', () async {
      final failing = SoundCloudResolver(
        httpGet: (_) async => throw Exception('down'),
      );
      expect(
        await failing.resolveSet('https://soundcloud.com/a/sets/s'),
        isNull,
      );
      expect(await failing.trackArtwork('https://soundcloud.com/a/t'), isNull);

      final empty = SoundCloudResolver(httpGet: (_) async => '<html></html>');
      expect(await empty.resolveSet('https://soundcloud.com/a/sets/s'), isNull);
    });

    test('استخراج client_id (32 محرفاً) بأنماطه الثلاثة', () {
      const id = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6';
      expect(SoundCloudResolver.extractClientId('client_id:"$id"'), id);
      expect(SoundCloudResolver.extractClientId('"client_id":"$id"'), id);
      expect(SoundCloudResolver.extractClientId('?client_id=$id&x=1'), id);
      expect(SoundCloudResolver.extractClientId('لا شيء هنا'), isNull);
    });
  });

  test('PlaylistPreview.totalDuration يتجاهل المدد الغائبة', () {
    const preview = PlaylistPreview(
      kind: PlaylistKind.youtube,
      title: 'ق',
      tracks: [
        PlaylistTrack(url: 'u1', title: 't1', duration: Duration(minutes: 2)),
        PlaylistTrack(url: 'u2', title: 't2'),
      ],
    );
    expect(preview.totalDuration, const Duration(minutes: 2));
  });
}
