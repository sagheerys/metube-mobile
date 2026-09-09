import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// A fake HTTP adapter: it captures the request and returns a scripted
/// response, with no real network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

(MeTubeApiClient, _FakeAdapter) makeClient(
  ResponseBody Function(RequestOptions) handler, {
  String? username,
  String? password,
}) {
  final adapter = _FakeAdapter(handler);
  final dio = Dio()..httpClientAdapter = adapter;
  final client = MeTubeApiClient(
    config: ServerConfig(
      baseUrl: 'https://metube.example.com/',
      username: username,
      password: password,
    ),
    dio: dio,
  );
  return (client, adapter);
}

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  group('ServerConfig', () {
    test('تطبيع الرابط: إزالة الشرطات الأخيرة والمسافات', () {
      expect(
        ServerConfig(baseUrl: ' https://s.com// ').baseUrl,
        'https://s.com',
      );
    });

    test('basicAuthHeader يُبنى من الاعتمادات', () {
      final config = ServerConfig(
        baseUrl: 'https://s.com',
        username: 'user',
        password: 'p@ss',
      );
      expect(
        config.basicAuthHeader,
        'Basic ${base64Encode(utf8.encode('user:p@ss'))}',
      );
      expect(ServerConfig(baseUrl: 'https://s.com').basicAuthHeader, isNull);
    });
  });

  group('testConnection (§2.1)', () {
    test(
      '200 + done/queue ⇒ نجاح، مع ترويسة Basic والاستعلام limit=1',
      () async {
        final (client, adapter) = makeClient(
          (o) => _json('{"done": [], "queue": []}'),
          username: 'u',
          password: 'p',
        );
        await client.testConnection();
        final req = adapter.requests.single;
        expect(req.uri.path, '/history');
        expect(req.uri.queryParameters['limit'], '1');
        expect(req.headers['Authorization'], startsWith('Basic '));
      },
    );

    test('HTML ⇒ NotMeTubeServerException', () async {
      final (client, _) = makeClient(
        (o) => _json('<html><body></body></html>'),
      );
      expect(client.testConnection(), throwsA(isA<NotMeTubeServerException>()));
    });

    test('JSON بلا queue ⇒ NotMeTubeServerException', () async {
      final (client, _) = makeClient((o) => _json('{"done": []}'));
      expect(client.testConnection(), throwsA(isA<NotMeTubeServerException>()));
    });

    test('401 ⇒ AuthFailureException', () async {
      final (client, _) = makeClient((o) => _json('unauthorized', status: 401));
      expect(client.testConnection(), throwsA(isA<AuthFailureException>()));
    });

    test('404 ⇒ NoApiException', () async {
      final (client, _) = makeClient((o) => _json('not found', status: 404));
      expect(client.testConnection(), throwsA(isA<NoApiException>()));
    });

    test('انقطاع النقل ⇒ NetworkException', () async {
      final (client, _) = makeClient(
        (o) => throw DioException.connectionError(
          requestOptions: o,
          reason: 'refused',
        ),
      );
      expect(client.testConnection(), throwsA(isA<NetworkException>()));
    });
  });

  group('fetchHistory (§2.3)', () {
    test('يفك نصاً plain ويبني HistoryResponse', () async {
      final (client, _) = makeClient(
        (o) => _json(
          '{"done": [{"url": "https://youtu.be/dQw4w9WgXcQ", '
          '"status": "finished", "filename": "a.mp4"}], "queue": []}',
        ),
      );
      final history = await client.fetchHistory();
      expect(history.done.single.canonicalUrl, 'https://youtu.be/dQw4w9WgXcQ');
    });
  });

  group('add (§2.2)', () {
    test(
      'يرسل url + quality، ويطبق قاعدة المنصة (رقمية+TikTok ⇒ best)',
      () async {
        final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
        await client.add(
          'https://www.tiktok.com/@u/video/7301234567890123456',
          Quality.q1080,
        );
        final req = adapter.requests.single;
        expect(req.uri.path, '/add');
        final body = json.decode(req.data as String) as Map;
        expect(body['quality'], 'best');
        expect(body['url'], contains('tiktok.com'));
      },
    );

    // **Playback compatibility** (field report 2026-09-03: "reels look
    // torn"). Measured against a real server: `format:mp4` alone produced
    // av1 inside mp4, and the two fields together produced h264/aac. So
    // **both** are asserted.
    test('توافق التشغيل يرسل download_type+format+codec للفيديو', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add(
        'https://youtu.be/dQw4w9WgXcQ',
        Quality.best,
        compatibleVideo: true,
      );
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body['format'], 'mp4');
      expect(body['codec'], 'h264');
      // **Without it, codec is ignored** — measured against a real server
      // twice.
      expect(body['download_type'], 'video');
    });

    /// **Facebook guards (ffprobe and yt-dlp measurements 2026-09-08).**
    /// `codec:h264` arrived and was recorded, and then MeTube's middle
    /// step, which carries **no codec filter**, picked av1 at 1440x2560,
    /// while `hd`, h264 at 720x1280, sat right behind it. The preset skips
    /// that step.
    test('توافق التشغيل + best ⇒ يرسل preset التوافق', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add(
        'https://m.facebook.com/watch/?v=161924316',
        Quality.best,
        compatibleVideo: true,
      );
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body['ytdl_options_presets'], [MeTubeApiClient.compatPreset]);
    });

    test(
      'جودة رقمية ⇒ لا preset (المُحدِّد الثابت يبتلع سقف الارتفاع)',
      () async {
        final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
        await client.add(
          'https://youtu.be/dQw4w9WgXcQ',
          Quality.q720,
          compatibleVideo: true,
        );
        final body = json.decode(adapter.requests.single.data as String) as Map;
        expect(
          body.containsKey('ytdl_options_presets'),
          isFalse,
          reason: 'وإلا نزل 1080p لمن طلب 720p',
        );
        expect(body['quality'], '720');
      },
    );

    test('الصوت لا preset له', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add(
        'https://youtu.be/dQw4w9WgXcQ',
        Quality.audio,
        compatibleVideo: true,
      );
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body.containsKey('ytdl_options_presets'), isFalse);
    });

    /// A server without the preset configured answers 400, and an
    /// open-source app runs on containers other than its author's. Without
    /// this fallback, **every download** fails.
    test('سيرفر يرفض الـpreset ⇒ إعادة المحاولة بلا preset لا فشل', () async {
      var calls = 0;
      final (client, adapter) = makeClient((o) {
        calls++;
        final body = json.decode(o.data as String) as Map;
        return body.containsKey('ytdl_options_presets')
            ? _json('preset not configured', status: 400)
            : _json('{"status": "ok"}');
      });

      await client.add(
        'https://m.facebook.com/watch/?v=1',
        Quality.best,
        compatibleVideo: true,
      );

      expect(calls, 2, reason: 'محاولة ثم رجوع');
      final second = json.decode(adapter.requests.last.data as String) as Map;
      expect(second.containsKey('ytdl_options_presets'), isFalse);
      expect(second['codec'], 'h264', reason: 'بقية التوافق تبقى');
    });

    test('فشل بلا preset لا يُعاد مرتين', () async {
      var calls = 0;
      final (client, _) = makeClient((o) {
        calls++;
        return _json('{"status": "error", "msg": "boom"}');
      });
      await expectLater(
        client.add(
          'https://youtu.be/dQw4w9WgXcQ',
          Quality.q720,
          compatibleVideo: true,
        ),
        throwsA(isA<ServerErrorException>()),
      );
      expect(calls, 1);
    });

    /// **Guards for "what we take for a single item stays single"** (field
    /// report 2026-09-08): an album URL that `PlaylistDetector` did not
    /// recognise downloaded **twenty clips** on the server with no
    /// selection screen, while the app knew of one task, and in Lite the
    /// other nineteen are orphaned after one is pulled and deleted.
    test('رابط مفرد يحمل حدّ عنصر واحد', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add(
        'https://soundcloud.com/artist/some-track',
        Quality.best,
      );
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body['playlist_item_limit'], 1);
    });

    test('صفحة فنان غير مكتشَفة تُعامل مفرداً ⇒ الحدّ يحميها', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add('https://soundcloud.com/jazzhopcafe', Quality.best);
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(
        body['playlist_item_limit'],
        1,
        reason: 'مقيس على سيرفر المالك: ألبوم من ٣ + حدّ 1 ⇒ نزل واحد',
      );
    });

    /// `watch?v=…&list=…` is **a recognised playlist** to
    /// `PlaylistDetector`, so it goes to the selection screen and never
    /// arrives here as a single item, and the limit is not imposed on it.
    test('watch مع list قائمة معروفة ⇒ بلا حدّ', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLabc123',
        Quality.best,
      );
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body.containsKey('playlist_item_limit'), isFalse);
    });

    test('رابط قائمة صريح لا يُحدّ — الدفعي يرسل كل مقطع وحده', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add(
        'https://soundcloud.com/artist/sets/album',
        Quality.best,
      );
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body.containsKey('playlist_item_limit'), isFalse);
    });

    test('توافق التشغيل لا يُرسل مع الصوت', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add(
        'https://youtu.be/dQw4w9WgXcQ',
        Quality.audio,
        compatibleVideo: true,
      );
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body.containsKey('format'), isFalse);
      expect(body.containsKey('codec'), isFalse);
      expect(body.containsKey('download_type'), isFalse);
      expect(body['quality'], 'audio');
    });

    /// **The contract changed by decision 2026-09-08**: the body used to be
    /// literally `{url, quality}` with no playback compatibility.
    /// `playlist_item_limit` was added because a link the app took for a
    /// single clip downloaded **twenty** on the server. That field stays
    /// the only permitted addition here, and this guard stops anything else
    /// leaking in.
    test('بلا توافق التشغيل: الجسم url+quality والحدّ لا غير', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add('https://youtu.be/dQw4w9WgXcQ', Quality.best);
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body.keys.toSet(), {'url', 'quality', 'playlist_item_limit'});
    });

    test('يوتيوب يحتفظ بالرقمية', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add('https://youtu.be/dQw4w9WgXcQ', Quality.q720);
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body['quality'], '720');
    });

    test('200 مع status=error + نص كوكيز ⇒ PlatformBlockedException', () async {
      final (client, _) = makeClient(
        (o) => _json(
          '{"status": "error", "msg": "Sign in to confirm you are not a bot"}',
        ),
      );
      expect(
        client.add('https://youtu.be/dQw4w9WgXcQ', Quality.best),
        throwsA(isA<PlatformBlockedException>()),
      );
    });

    test('خطأ عادي ⇒ ServerErrorException برسالة السيرفر', () async {
      final (client, _) = makeClient(
        (o) => _json('{"status": "error", "msg": "Unsupported URL"}'),
      );
      expect(
        client.add('https://example.com/x', Quality.best),
        throwsA(
          isA<ServerErrorException>().having(
            (e) => e.detail,
            'detail',
            'Unsupported URL',
          ),
        ),
      );
    });

    test('خطأ Map (error كائن) يُسطّح نصاً', () async {
      final (client, _) = makeClient(
        (o) => _json('{"error": {"code": 400, "msg": "bad url"}}'),
      );
      expect(
        client.add('https://example.com/x', Quality.best),
        throwsA(isA<ServerErrorException>()),
      );
    });
  });

  group('delete (§2.5)', () {
    test('الحمولة: ids روابط كاملة + where=done', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.delete(['https://www.youtube.com/watch?v=dQw4w9WgXcQ']);
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body['ids'], ['https://www.youtube.com/watch?v=dQw4w9WgXcQ']);
      expect(body['where'], 'done');
    });
  });

  group('downloadUrl (§2.4)', () {
    test('ترميز الاسم العربي بالمسافات', () {
      final (client, _) = makeClient((o) => _json('{}'));
      expect(
        client.downloadUrl('ملف جميل.mp4'),
        'https://metube.example.com/download/${Uri.encodeComponent('ملف جميل.mp4')}',
      );
    });

    // **A title truncated with dots is a legitimate name (field report
    // 2026-09-03).** yt-dlp truncates long titles with an ellipsis, and our
    // guard rejected every name containing `..`, so the clip failed with
    // "unsafe filename" while a real server served that very name with HTTP
    // 206.
    for (final good in [
      'كهرباء.  مدر... [2077436096300945409].mp4',
      'a..b.mp4',
      'clip....webm',
    ]) {
      test('حارس المسار يقبل "$good"', () {
        final (client, _) = makeClient((o) => _json('{}'));
        expect(
          client.downloadUrl(good),
          'https://metube.example.com/download/${Uri.encodeComponent(good)}',
        );
      });
    }

    for (final bad in ['', '.', '..', '../secret', 'a/b.mp4', r'a\b.mp4']) {
      test('حارس المسار يرفض "$bad"', () {
        final (client, _) = makeClient((o) => _json('{}'));
        expect(
          () => client.downloadUrl(bad),
          throwsA(isA<UnsafeFilenameException>()),
        );
      });
    }
  });

  test('streamingHeaders تحمل Basic وkeep-alive', () {
    final (client, _) = makeClient(
      (o) => _json('{}'),
      username: 'u',
      password: 'p',
    );
    expect(client.streamingHeaders['Authorization'], startsWith('Basic '));
    expect(client.streamingHeaders['Connection'], 'keep-alive');
  });

  /// **Critical defect ح-1** — `downloadTo` had not a single test, and that
  /// is what hid the fact that `validateStatus < 600` let an error page be
  /// saved as **a successful media file**, after which the original was
  /// deleted from the server.
  group('downloadTo (§2.4) — حالة HTTP لا تمرّ بصمت', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mtf_dl_');
    });
    tearDown(() => tempDir.delete(recursive: true));

    String path(String name) => '${tempDir.path}${Platform.pathSeparator}$name';

    Future<void> expectRejected(int status, TypeMatcher<Object> matcher) async {
      final (client, _) = makeClient(
        (o) => ResponseBody.fromString(
          '<html>لست ملفاً</html>',
          status,
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      );
      await expectLater(
        client.downloadTo('clip.mp4', path('out_$status.mp4')),
        throwsA(matcher),
      );
    }

    test(
      '401 ⇒ AuthFailure لا «نجاح»',
      () => expectRejected(401, isA<AuthFailureException>()),
    );
    test(
      '403 ⇒ AuthFailure',
      () => expectRejected(403, isA<AuthFailureException>()),
    );
    test('404 ⇒ NoApi', () => expectRejected(404, isA<NoApiException>()));
    test(
      '500 ⇒ ServerError',
      () => expectRejected(500, isA<ServerErrorException>()),
    );
    test(
      '502 ⇒ ServerError (وكيل عكسي عابر)',
      () => expectRejected(502, isA<ServerErrorException>()),
    );

    test('200 ⇒ يُكتب الملف بلا رمي', () async {
      final (client, _) = makeClient(
        (o) => ResponseBody.fromString(
          'MEDIA',
          200,
          headers: {
            Headers.contentTypeHeader: ['video/mp4'],
          },
        ),
      );
      final out = path('ok.mp4');
      await client.downloadTo('clip.mp4', out);
      expect(File(out).readAsStringSync(), 'MEDIA');
    });
  });

  group('fileExists — الحارس الرخيص قبل تسليم الرابط للمنصة', () {
    test('206 على نطاق بايت واحد ⇒ موجود', () async {
      final (client, adapter) = makeClient((_) => _json('x', status: 206));
      expect(await client.fileExists('a.mp4'), isTrue);
      expect(adapter.requests.single.headers['Range'], 'bytes=0-0');
    });

    test('404 ⇒ غير موجود (بلا رمي)', () async {
      final (client, _) = makeClient((_) => _json('no', status: 404));
      // The guard: one dead record in `/history` used to be handed to
      // MediaMetadataRetriever, freezing thumbnail probing for 80 seconds
      // every session.
      expect(await client.fileExists('gone.mp4'), isFalse);
    });

    test('اسم ملف خبيث ⇒ false ولا يُبنى له رابط (القاعدة 9)', () async {
      final (client, adapter) = makeClient((_) => _json('x', status: 206));
      expect(await client.fileExists('../etc/passwd'), isFalse);
      expect(adapter.requests, isEmpty);
    });
  });
}
