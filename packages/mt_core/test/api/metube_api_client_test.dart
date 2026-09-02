import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// محوّل HTTP مزيف: يلتقط الطلب ويعيد استجابة مبرمجة — بلا شبكة حقيقية.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
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

ResponseBody _json(String body, {int status = 200}) =>
    ResponseBody.fromString(body, status,
        headers: {Headers.contentTypeHeader: ['application/json']});

void main() {
  group('ServerConfig', () {
    test('تطبيع الرابط: إزالة الشرطات الأخيرة والمسافات', () {
      expect(ServerConfig(baseUrl: ' https://s.com// ').baseUrl,
          'https://s.com');
    });

    test('basicAuthHeader يُبنى من الاعتمادات', () {
      final config = ServerConfig(baseUrl: 'https://s.com',
          username: 'yasir', password: 'p@ss');
      expect(config.basicAuthHeader,
          'Basic ${base64Encode(utf8.encode('yasir:p@ss'))}');
      expect(ServerConfig(baseUrl: 'https://s.com').basicAuthHeader, isNull);
    });
  });

  group('testConnection (§2.1)', () {
    test('200 + done/queue ⇒ نجاح، مع ترويسة Basic والاستعلام limit=1',
        () async {
      final (client, adapter) =
          makeClient((o) => _json('{"done": [], "queue": []}'),
              username: 'u', password: 'p');
      await client.testConnection();
      final req = adapter.requests.single;
      expect(req.uri.path, '/history');
      expect(req.uri.queryParameters['limit'], '1');
      expect(req.headers['Authorization'], startsWith('Basic '));
    });

    test('HTML ⇒ NotMeTubeServerException', () async {
      final (client, _) = makeClient((o) => _json('<html><body></body></html>'));
      expect(client.testConnection(),
          throwsA(isA<NotMeTubeServerException>()));
    });

    test('JSON بلا queue ⇒ NotMeTubeServerException', () async {
      final (client, _) = makeClient((o) => _json('{"done": []}'));
      expect(client.testConnection(),
          throwsA(isA<NotMeTubeServerException>()));
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
      final (client, _) = makeClient((o) => throw DioException.connectionError(
          requestOptions: o, reason: 'refused'));
      expect(client.testConnection(), throwsA(isA<NetworkException>()));
    });
  });

  group('fetchHistory (§2.3)', () {
    test('يفك نصاً plain ويبني HistoryResponse', () async {
      final (client, _) = makeClient((o) => _json(
          '{"done": [{"url": "https://youtu.be/dQw4w9WgXcQ", '
          '"status": "finished", "filename": "a.mp4"}], "queue": []}'));
      final history = await client.fetchHistory();
      expect(history.done.single.canonicalUrl, 'https://youtu.be/dQw4w9WgXcQ');
    });
  });

  group('add (§2.2)', () {
    test('يرسل url + quality، ويطبق قاعدة المنصة (رقمية+TikTok ⇒ best)',
        () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add(
          'https://www.tiktok.com/@u/video/7301234567890123456', Quality.q1080);
      final req = adapter.requests.single;
      expect(req.uri.path, '/add');
      final body = json.decode(req.data as String) as Map;
      expect(body['quality'], 'best');
      expect(body['url'], contains('tiktok.com'));
    });

    test('يوتيوب يحتفظ بالرقمية', () async {
      final (client, adapter) = makeClient((o) => _json('{"status": "ok"}'));
      await client.add('https://youtu.be/dQw4w9WgXcQ', Quality.q720);
      final body = json.decode(adapter.requests.single.data as String) as Map;
      expect(body['quality'], '720');
    });

    test('200 مع status=error + نص كوكيز ⇒ PlatformBlockedException',
        () async {
      final (client, _) = makeClient((o) => _json(
          '{"status": "error", "msg": "Sign in to confirm you are not a bot"}'));
      expect(client.add('https://youtu.be/dQw4w9WgXcQ', Quality.best),
          throwsA(isA<PlatformBlockedException>()));
    });

    test('خطأ عادي ⇒ ServerErrorException برسالة السيرفر', () async {
      final (client, _) = makeClient(
          (o) => _json('{"status": "error", "msg": "Unsupported URL"}'));
      expect(
          client.add('https://example.com/x', Quality.best),
          throwsA(isA<ServerErrorException>()
              .having((e) => e.detail, 'detail', 'Unsupported URL')));
    });

    test('خطأ Map (error كائن) يُسطّح نصاً', () async {
      final (client, _) = makeClient(
          (o) => _json('{"error": {"code": 400, "msg": "bad url"}}'));
      expect(client.add('https://example.com/x', Quality.best),
          throwsA(isA<ServerErrorException>()));
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
      expect(client.downloadUrl('ملف جميل.mp4'),
          'https://metube.example.com/download/${Uri.encodeComponent('ملف جميل.mp4')}');
    });

    for (final bad in ['', '../secret', 'a/b.mp4', r'a\b.mp4']) {
      test('حارس المسار يرفض "$bad"', () {
        final (client, _) = makeClient((o) => _json('{}'));
        expect(() => client.downloadUrl(bad),
            throwsA(isA<UnsafeFilenameException>()));
      });
    }
  });

  test('streamingHeaders تحمل Basic وkeep-alive', () {
    final (client, _) =
        makeClient((o) => _json('{}'), username: 'u', password: 'p');
    expect(client.streamingHeaders['Authorization'], startsWith('Basic '));
    expect(client.streamingHeaders['Connection'], 'keep-alive');
  });

  /// **العطل الحرج ح-1** — كان `downloadTo` بلا اختبار واحد، وهو ما
  /// أخفى أن `validateStatus < 600` يجعل صفحة الخطأ تُحفظ **ملفَ وسائط
  /// ناجحاً** ثم يُحذف الأصل من السيرفر.
  group('downloadTo (§2.4) — حالة HTTP لا تمرّ بصمت', () {
    late Directory tempDir;
    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mtf_dl_');
    });
    tearDown(() => tempDir.delete(recursive: true));

    String path(String name) =>
        '${tempDir.path}${Platform.pathSeparator}$name';

    Future<void> expectRejected(int status, TypeMatcher<Object> matcher) async {
      final (client, _) = makeClient((o) => ResponseBody.fromString(
            '<html>لست ملفاً</html>',
            status,
            headers: {
              Headers.contentTypeHeader: ['text/html']
            },
          ));
      await expectLater(
        client.downloadTo('clip.mp4', path('out_$status.mp4')),
        throwsA(matcher),
      );
    }

    test('401 ⇒ AuthFailure لا «نجاح»', () => expectRejected(401,
        isA<AuthFailureException>()));
    test('403 ⇒ AuthFailure', () => expectRejected(403,
        isA<AuthFailureException>()));
    test('404 ⇒ NoApi', () => expectRejected(404, isA<NoApiException>()));
    test('500 ⇒ ServerError', () => expectRejected(500,
        isA<ServerErrorException>()));
    test('502 ⇒ ServerError (وكيل عكسي عابر)', () => expectRejected(502,
        isA<ServerErrorException>()));

    test('200 ⇒ يُكتب الملف بلا رمي', () async {
      final (client, _) = makeClient((o) => ResponseBody.fromString(
            'MEDIA',
            200,
            headers: {
              Headers.contentTypeHeader: ['video/mp4']
            },
          ));
      final out = path('ok.mp4');
      await client.downloadTo('clip.mp4', out);
      expect(File(out).readAsStringSync(), 'MEDIA');
    });
  });
}
