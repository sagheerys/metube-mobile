import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];
  final List<String> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      bodies.add(
        // The multipart body is text plus the file, and the file here is
        // always text too, so latin1 keeps every byte readable.
        latin1.decode(chunks.expand((chunk) => chunk).toList()),
      );
    } else {
      bodies.add('');
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

(MeTubeApiClient, _Adapter) _makeClient(
  ResponseBody Function(RequestOptions) handler,
) {
  final adapter = _Adapter(handler);
  final client = MeTubeApiClient(
    config: ServerConfig(baseUrl: 'https://metube.example.com'),
    dio: Dio()..httpClientAdapter = adapter,
  );
  return (client, adapter);
}

/// **Cookies (§2.8).**
///
/// Until now a platform asking for a login was a dead end: the app said
/// "the server admin should refresh the cookies" and stopped, even when
/// the person reading it *was* the admin. These three calls turn that
/// message into something that can be acted on from the phone.
void main() {
  group('hasCookies', () {
    test('reads has_cookies from the server', () async {
      final (client, adapter) = _makeClient(
        (_) => _json('{"status":"ok","has_cookies":true}'),
      );
      expect(await client.hasCookies(), isTrue);
      expect(adapter.requests.single.path, contains('/cookie-status'));
    });

    test('false is false, not unknown', () async {
      final (client, _) = _makeClient(
        (_) => _json('{"status":"ok","has_cookies":false}'),
      );
      expect(await client.hasCookies(), isFalse);
    });

    test('an older MeTube with no such endpoint gives NULL: "no cookies" and '
        '"this server cannot say" must not look the same', () async {
      final (client, _) = _makeClient((_) => _json('nope', status: 404));
      expect(await client.hasCookies(), isNull);
    });

    test('a body without the field is unknown too', () async {
      final (client, _) = _makeClient((_) => _json('{"status":"ok"}'));
      expect(await client.hasCookies(), isNull);
      final (other, _) = _makeClient((_) => _json('<html>'));
      expect(await other.hasCookies(), isNull);
    });
  });

  group('uploadCookies', () {
    test('sends multipart under the name the server reads', () async {
      final (client, adapter) = _makeClient(
        (_) => _json('{"status":"ok","msg":"Cookies uploaded (12 bytes)"}'),
      );
      await client.uploadCookies(utf8.encode('# Netscape\n'));

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, contains('/upload-cookies'));
      expect(request.headers['content-type'], contains('multipart/form-data'));
      // **The field must be called `cookies`**: the server reads the first
      // part and rejects any other name outright.
      expect(adapter.bodies.single, contains('name="cookies"'));
      expect(adapter.bodies.single, contains('# Netscape'));
    });

    test(
      'a file over the server\'s 1MB ceiling is refused BEFORE the upload: '
      'a phone\'s upload is the slowest link, and the answer is known',
      () async {
        final (client, adapter) = _makeClient((_) => _json('{"status":"ok"}'));
        expect(
          () => client.uploadCookies(List.filled(1000001, 0x41)),
          throwsA(isA<CookiesTooLargeException>()),
        );
        expect(adapter.requests, isEmpty);
      },
    );

    test('exactly at the ceiling is allowed', () async {
      final (client, adapter) = _makeClient((_) => _json('{"status":"ok"}'));
      await client.uploadCookies(List.filled(1000000, 0x41));
      expect(adapter.requests, hasLength(1));
    });

    test('an empty file is refused, and nothing is sent', () async {
      final (client, adapter) = _makeClient((_) => _json('{"status":"ok"}'));
      expect(
        () => client.uploadCookies(const []),
        throwsA(isA<ServerErrorException>()),
      );
      expect(adapter.requests, isEmpty);
    });

    test('a server error in the body is reported', () async {
      final (client, _) = _makeClient(
        (_) => _json('{"status":"error","msg":"No cookies file provided"}'),
      );
      expect(
        () => client.uploadCookies(utf8.encode('x')),
        throwsA(isA<ServerErrorException>()),
      );
    });
  });

  group('deleteCookies', () {
    test('posts to delete-cookies', () async {
      final (client, adapter) = _makeClient((_) => _json('{"status":"ok"}'));
      await client.deleteCookies();
      expect(adapter.requests.single.path, contains('/delete-cookies'));
    });

    test('cookies configured by the operator in YTDL_OPTIONS cannot be deleted '
        'from here, and the server says why — so the message is passed on '
        'rather than swallowed', () async {
      const msg =
          'Cookies are configured manually via YTDL_OPTIONS (cookiefile). '
          'Remove or change that setting manually; UI delete only removes '
          'uploaded cookies.';
      final (client, _) = _makeClient(
        (_) => _json(jsonEncode({'status': 'error', 'msg': msg}), status: 400),
      );
      await expectLater(
        client.deleteCookies(),
        throwsA(
          isA<ServerErrorException>().having(
            (e) => e.detail,
            'detail',
            contains('YTDL_OPTIONS'),
          ),
        ),
      );
    });

    test('nothing to delete is an error, not a silent success', () async {
      final (client, _) = _makeClient(
        (_) => _json(
          '{"status":"error","msg":"No uploaded cookies to delete"}',
          status: 400,
        ),
      );
      expect(client.deleteCookies(), throwsA(isA<ServerErrorException>()));
    });
  });
}
