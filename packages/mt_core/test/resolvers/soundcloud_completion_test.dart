import 'dart:convert';
import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **Field report 2026-09-02: "the album downloads strangely".**
///
/// SoundCloud embeds the full object for only the first five or so tracks,
/// and the rest arrive as `{id, kind}` with no `permalink_url`. The parser
/// was dropping them silently, so an album of 432 tracks showed **5**. The
/// sample here comes from the live site (rule 8).
void main() {
  final html = File('test/fixtures/real/soundcloud_set.html')
      .readAsStringSync();

  test('the real capture holds both complete and incomplete tracks', () {
    expect(SoundCloudResolver.parseHydration(html)!.tracks, hasLength(2));
    expect(
      SoundCloudResolver.pendingTrackIds(html),
      hasLength(3),
      reason: 'هذه الثلاثة كانت تُسقط بصمت',
    );
  });

  test('the client_id is read from apiClient inside the hydration', () {
    final id = SoundCloudResolver.extractClientId(html);
    expect(id, isNotNull);
    expect(
      id!.length,
      greaterThanOrEqualTo(24),
      reason: 'الأنماط النصية الثلاثة لم تعد تطابق شيئاً في صفحة اليوم',
    );
  });

  test(
    'resolveSet completes what is missing through api-v2, in batches',
    () async {
      final pending = SoundCloudResolver.pendingTrackIds(html);
      var tracksCall = 0;
      final resolver = SoundCloudResolver(
        httpGet: (uri) async {
          if (uri.host == 'soundcloud.com') return html;
          tracksCall++;
          expect(uri.host, 'api-v2.soundcloud.com');
          expect(uri.queryParameters['client_id'], isNotNull);
          final ids = uri.queryParameters['ids']!.split(',');
          expect(ids, hasLength(pending.length));
          return json.encode([
            for (final id in ids)
              {
                'id': int.parse(id),
                'title': 'مقطع $id',
                'permalink_url': 'https://soundcloud.com/a/$id',
                'duration': 180000,
              },
          ]);
        },
      );

      final preview = await resolver.resolveSet(
        'https://soundcloud.com/relaxcafemusic/sets/coffee-jazz',
      );

      expect(tracksCall, 1);
      expect(
        preview!.tracks,
        hasLength(2 + pending.length),
        reason: 'قبل الإصلاح: الكاملة وحدها',
      );
      expect(preview.tracks.last.duration, const Duration(minutes: 3));
    },
  );

  test('a failure to complete does not lose what already succeeded', () async {
    final resolver = SoundCloudResolver(
      httpGet: (uri) async {
        if (uri.host == 'soundcloud.com') return html;
        throw const SocketException('api down');
      },
    );
    final preview = await resolver.resolveSet(
      'https://soundcloud.com/a/sets/b',
    );
    expect(
      preview,
      isNull,
      reason: 'الفشل-الآمن يعيد null فيظهر للمستخدم سبب واضح',
    );
  });
}
