import 'dart:convert';
import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **بلاغ المالك 2026-09-02: «الألبوم يُحمَّل بطريقة غريبة».**
///
/// ساوندكلاود يضمّن الكائن الكامل لأول ~5 مقاطع فقط، والبقية تصل
/// `{id, kind}` بلا `permalink_url` — وكان المحلل يُسقطها بصمت، فألبوم
/// من 432 مقطعاً يظهر **5**. العينة هنا من الموقع الحقيقي (القاعدة 8).
void main() {
  final html =
      File('test/fixtures/real/soundcloud_set.html').readAsStringSync();

  test('العينة الحقيقية فيها مقاطع كاملة وأخرى ناقصة', () {
    expect(SoundCloudResolver.parseHydration(html)!.tracks, hasLength(2));
    expect(SoundCloudResolver.pendingTrackIds(html), hasLength(3),
        reason: 'هذه الثلاثة كانت تُسقط بصمت');
  });

  test('client_id يُقرأ من apiClient في hydration', () {
    final id = SoundCloudResolver.extractClientId(html);
    expect(id, isNotNull);
    expect(id!.length, greaterThanOrEqualTo(24),
        reason: 'الأنماط النصية الثلاثة لم تعد تطابق شيئاً في صفحة اليوم');
  });

  test('resolveSet يُكمل الناقص عبر api-v2 بدفعات', () async {
    final pending = SoundCloudResolver.pendingTrackIds(html);
    var tracksCall = 0;
    final resolver = SoundCloudResolver(httpGet: (uri) async {
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
          }
      ]);
    });

    final preview = await resolver
        .resolveSet('https://soundcloud.com/relaxcafemusic/sets/coffee-jazz');

    expect(tracksCall, 1);
    expect(preview!.tracks, hasLength(2 + pending.length),
        reason: 'قبل الإصلاح: الكاملة وحدها');
    expect(preview.tracks.last.duration, const Duration(minutes: 3));
  });

  test('فشل الإكمال لا يُضيّع ما نجح', () async {
    final resolver = SoundCloudResolver(httpGet: (uri) async {
      if (uri.host == 'soundcloud.com') return html;
      throw const SocketException('api down');
    });
    final preview =
        await resolver.resolveSet('https://soundcloud.com/a/sets/b');
    expect(preview, isNull,
        reason: 'الفشل-الآمن يعيد null فيظهر للمستخدم سبب واضح');
  });
}
