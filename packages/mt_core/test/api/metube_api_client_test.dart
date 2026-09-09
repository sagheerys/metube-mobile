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
    test('normalising the URL: trailing slashes and spaces are removed', () {
      expect(
        ServerConfig(baseUrl: ' https://s.com// ').baseUrl,
        'https://s.com',
      );
    });

    test('basicAuthHeader is built from the credentials', () {
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
      '200 with done and queue succeeds, sending the Basic header and limit=1',
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

    test('JSON without queue raises NotMeTubeServerException', () async {
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

    test('a dropped connection raises NetworkException', () async {
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
    test('it decodes a plain-text body and builds a HistoryResponse', () async {
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
    test('it sends url and quality, applying the platform rule: a numeric quality on TikTok becomes best', () async {
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
    });

    // **Playback compatibility** (field report 2026-09-03: "reels look
    // torn"). Measured against a real server: `format:mp4` alone produced
    // av1 inside mp4, and the two fields together produced h264/aac. So
    // **both** are asserted.
    test(
      'playback compatibility sends download_type, format and codec for video',
      () async {
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
      },
    );

    /// **Facebook guards (ffprobe and yt-dlp measurements 2026-09-08).**
    /// `codec:h264` arrived and was recorded, and then MeTube's middle
    /// step, which carries **no codec filter**, picked av1 at 1440x2560,
    /// while `hd`, h264 at 720x1280, sat right behind it. The preset skips
    /// that step.
    test(
      'playback compatibility with best sends the compatibility preset',
      () async {
        final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
        await client.add(
          'https://m.facebook.com/watch/?v=161924316',
          Quality.best,
          compatibleVideo: true,
        );
        final body = json.decode(adapter.requests.single.data as String) as Map;
        expect(body['ytdl_options_presets'], [MeTubeApiClient.compatPreset]);
      },
    );

    test('a numeric quality sends no preset: the fixed selector would swallow the height cap', () async {
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
    });

    test('audio has no preset', () async {
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
    test('a server that refuses the preset is retried without it rather than failing', () async {
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

    test('a failure with no preset is not retried twice', () async {
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
    test('a single URL carries the one-item limit', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add(
        'https://soundcloud.com/artist/some-track',
        Quality.best,
      );
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body['playlist_item_limit'], 1);
    });

    test('an undetected artist page is treated as single, and the limit protects it', () async {
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
    test('a watch URL with a recognised list carries no limit', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLabc123',
        Quality.best,
      );
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body.containsKey('playlist_item_limit'), isFalse);
    });

    test('an explicit playlist URL is not limited: the batch screen sends each clip on its own', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add(
        'https://soundcloud.com/artist/sets/album',
        Quality.best,
      );
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body.containsKey('playlist_item_limit'), isFalse);
    });

    test('playback compatibility is never sent with audio', () async {
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
    test('without playback compatibility the body is url, quality and the limit, nothing else', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add('https://youtu.be/dQw4w9WgXcQ', Quality.best);
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body.keys.toSet(), {'url', 'quality', 'playlist_item_limit'});
    });

    test('YouTube keeps the numeric quality', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add('https://youtu.be/dQw4w9WgXcQ', Quality.q720);
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body['quality'], '720');
    });

    test('200 with status=error and a cookie message raises PlatformBlockedException', () async {
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

    test("an ordinary error raises ServerErrorException carrying the server's message", () async {
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

    test('an error given as a map is flattened to text', () async {
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
    test('the payload: ids are full URLs, with where=done', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.delete(['https://www.youtube.com/watch?v=dQw4w9WgXcQ']);
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body['ids'], ['https://www.youtube.com/watch?v=dQw4w9WgXcQ']);
      expect(body['where'], 'done');
    });
  });

  group('downloadUrl (§2.4)', () {
    test('encoding an Arabic name with spaces', () {
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
      test('the path guard accepts "$good"', () {
        final (client, _) = makeClient((o) => _json('{}'));
        expect(
          client.downloadUrl(good),
          'https://metube.example.com/download/${Uri.encodeComponent(good)}',
        );
      });
    }

    for (final bad in ['', '.', '..', '../secret', 'a/b.mp4', r'a\b.mp4']) {
      test('the path guard rejects "$bad"', () {
        final (client, _) = makeClient((o) => _json('{}'));
        expect(
          () => client.downloadUrl(bad),
          throwsA(isA<UnsafeFilenameException>()),
        );
      });
    }
  });

  test('streamingHeaders carry Basic and keep-alive', () {
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
  group('downloadTo: an HTTP status never passes silently', () {
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
      '401 raises AuthFailure rather than reporting success',
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
      '502 raises ServerError, a passing reverse proxy',
      () => expectRejected(502, isA<ServerErrorException>()),
    );

    test('200 writes the file without throwing', () async {
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

  group(
    'fileExists: the cheap guard before a URL is handed to the platform',
    () {
      test('206 on a one-byte range means it exists', () async {
        final (client, adapter) = makeClient((_) => _json('x', status: 206));
        expect(await client.fileExists('a.mp4'), isTrue);
        expect(adapter.requests.single.headers['Range'], 'bytes=0-0');
      });

      test('404 means it does not exist, without throwing', () async {
        final (client, _) = makeClient((_) => _json('no', status: 404));
        // The guard: one dead record in `/history` used to be handed to
        // MediaMetadataRetriever, freezing thumbnail probing for 80 seconds
        // every session.
        expect(await client.fileExists('gone.mp4'), isFalse);
      });

      test(
        'a malicious filename returns false, and no URL is built for it',
        () async {
          final (client, adapter) = makeClient((_) => _json('x', status: 206));
          expect(await client.fileExists('../etc/passwd'), isFalse);
          expect(adapter.requests, isEmpty);
        },
      );
    },
  );
}
