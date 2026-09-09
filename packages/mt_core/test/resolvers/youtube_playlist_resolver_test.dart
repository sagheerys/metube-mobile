import 'dart:convert';
import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **Field report 2026-09-02: "the playlist shows an empty page".**
///
/// The cause, proven by running it: `youtube_explode_dart` emits **zero
/// items** for a playlist counting 19 (in 2.5.3 and 3.1.0 alike), because
/// YouTube replaced `playlistVideoRenderer` with `lockupViewModel`. These
/// tests run against **a real saved InnerTube response** (rule 8).
void main() {
  final raw = File('test/fixtures/real/youtube_browse.json').readAsStringSync();
  final browse = json.decode(raw);

  group('InnertubeParser: the new view-model structure', () {
    test('it extracts the clips from lockupViewModel', () {
      final preview = InnertubeParser.parseBrowse(browse);
      expect(preview, isNotNull);
      expect(
        preview!.tracks,
        isNotEmpty,
        reason: 'الحزمة الجاهزة كانت تعيد صفر هنا',
      );
      expect(preview.kind, PlaylistKind.youtube);
      expect(preview.title, 'Top Trending Videos of the Week');
    });

    test(
      'every clip: a full watch URL, a title, a duration and a stable cover',
      () {
        final track = InnertubeParser.parseBrowse(browse)!.tracks.first;
        expect(track.url, startsWith('https://www.youtube.com/watch?v='));
        expect(UrlKit.youtubeVideoId(track.url), hasLength(11));
        expect(track.title, isNotEmpty);
        expect(track.duration, isNotNull);
        expect(track.duration!.inSeconds, greaterThan(0));
        expect(track.thumbnail, contains('i.ytimg.com'));
        expect(
          track.thumbnail,
          isNot(contains('sqp=')),
          reason: 'روابط sqp مؤقتة تنتهي صلاحيتها',
        );
      },
    );

    test('it picks the continuation token out of the nested shape', () {
      expect(InnertubeParser.continuationToken(browse), isNotNull);
    });

    test('a response with no clips gives null, not an empty list', () {
      expect(InnertubeParser.parseBrowse({'contents': []}), isNull);
    });

    test('parseClock reads mm:ss and h:mm:ss and rejects everything else', () {
      expect(
        InnertubeParser.parseClock('16:09'),
        const Duration(minutes: 16, seconds: 9),
      );
      expect(
        InnertubeParser.parseClock('1:02:33'),
        const Duration(hours: 1, minutes: 2, seconds: 33),
      );
      expect(InnertubeParser.parseClock('LIVE'), isNull);
      expect(InnertubeParser.parseClock(null), isNull);
    });
  });

  group('YoutubePlaylistResolver, with no network', () {
    test('it gathers the pages until the continuation stops', () async {
      var calls = 0;
      final resolver = YoutubePlaylistResolver(
        httpPost: (uri, body) async {
          calls++;
          final payload = body as Map;
          expect(uri.host, 'www.youtube.com');
          if (calls == 1) {
            expect(payload['browseId'], 'VLPLtest');
            return raw; // a first page with a continuation token
          }
          expect(payload['continuation'], isNotNull);
          return json.encode({'contents': []}); // no more
        },
      );

      final preview = await resolver.resolve(
        'https://www.youtube.com/playlist?list=PLtest',
      );
      expect(preview, isNotNull);
      expect(calls, 2, reason: 'صفحة ثانية تُطلب ثم يتوقف');
      expect(preview!.tracks, isNotEmpty);
    });

    test('a network failure gives null and does not throw', () async {
      final resolver = YoutubePlaylistResolver(
        httpPost: (uri, body) async => throw const SocketException('down'),
      );
      expect(
        await resolver.resolve('https://www.youtube.com/playlist?list=PLx'),
        isNull,
      );
    });
  });

  group('PlaylistDetector: what really is a playlist', () {
    test('a single video URL with no list is not a playlist', () {
      // The URL that was reported: it has no `list=` in it at all.
      expect(
        PlaylistDetector.detect('https://youtu.be/i_OHQH4-M2Y?si=jnr8PIx'),
        PlaylistKind.none,
      );
    });

    test('a playlist page is YouTube', () {
      expect(
        PlaylistDetector.detect(
          'https://www.youtube.com/playlist?list=PLbpi6&si=x',
        ),
        PlaylistKind.youtube,
      );
    });

    test('mix and private playlists are treated as a single URL', () {
      for (final id in ['RDMM', 'RDAMVM123', 'WL', 'LL']) {
        expect(
          PlaylistDetector.detect(
            'https://www.youtube.com/watch?v=abc&list=$id',
          ),
          PlaylistKind.none,
          reason: '$id لا يُقرأ بلا حساب أو لا عناصر ثابتة له',
        );
      }
    });

    test('a SoundCloud album is SoundCloud', () {
      expect(
        PlaylistDetector.detect('https://soundcloud.com/a/sets/b'),
        PlaylistKind.soundcloud,
      );
    });
  });
}
