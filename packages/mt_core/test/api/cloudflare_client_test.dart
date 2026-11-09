import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// Cloudflare Access headers on every request to the server.
///
/// The risk this file guards is quiet: one endpoint forgetting the headers
/// works at home and fails only behind Access, where the person on the other
/// end sees "not a MeTube server". So the assertion is made over **every**
/// request an operation produced, not over the first one.
const _id = '4c1f0d7a.access';
const _secret = '9a7e11c0b2d4f6a8';
const _idHeader = 'CF-Access-Client-Id';
const _secretHeader = 'CF-Access-Client-Secret';

class _Recorder implements HttpClientAdapter {
  _Recorder(this.handler);

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

ResponseBody _ok(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

(MeTubeApiClient, _Recorder) _client(
  ResponseBody Function(RequestOptions) handler, {
  String baseUrl = 'https://metube.example.com',
  String? username,
  String? password,
  CloudflareAccess? access,
}) {
  final adapter = _Recorder(handler);
  final client = MeTubeApiClient(
    config: ServerConfig(
      baseUrl: baseUrl,
      username: username,
      password: password,
      access: access,
    ),
    dio: Dio()..httpClientAdapter = adapter,
  );
  return (client, adapter);
}

final _pair = CloudflareAccess(clientId: _id, clientSecret: _secret);

/// An Engine.IO conversation, enough for `liveUpdates` to join and end.
ResponseBody _liveServer(RequestOptions o) {
  if (o.method == 'POST') return ResponseBody.fromString('ok', 200);
  if (!o.queryParameters.containsKey('sid')) {
    return ResponseBody.fromString(
      '0{"sid":"s1","pingInterval":25000,"pingTimeout":20000}',
      200,
    );
  }
  return ResponseBody.fromString('1', 200);
}

void _expectAll(List<RequestOptions> requests, {required bool carried}) {
  expect(requests, isNotEmpty, reason: 'the operation sent nothing');
  for (final r in requests) {
    if (carried) {
      expect(r.headers[_idHeader], _id, reason: '${r.method} ${r.uri}');
      expect(r.headers[_secretHeader], _secret, reason: '${r.method} ${r.uri}');
    } else {
      expect(r.headers.containsKey(_idHeader), isFalse, reason: '${r.uri}');
      expect(r.headers.containsKey(_secretHeader), isFalse, reason: '${r.uri}');
    }
  }
}

void main() {
  group('a complete pair on an https server rides on every request', () {
    test('testConnection', () async {
      final (c, a) = _client(
        (_) => _ok('{"done":[],"queue":[]}'),
        access: _pair,
      );
      await c.testConnection();
      _expectAll(a.requests, carried: true);
    });

    test('fetchHistory', () async {
      final (c, a) = _client(
        (_) => _ok('{"done":[],"queue":[]}'),
        access: _pair,
      );
      await c.fetchHistory();
      _expectAll(a.requests, carried: true);
    });

    test('add', () async {
      final (c, a) = _client((_) => _ok('{"status":"ok"}'), access: _pair);
      await c.add('https://www.youtube.com/watch?v=dQw4w9WgXcQ', Quality.best);
      _expectAll(a.requests, carried: true);
    });

    test('delete', () async {
      final (c, a) = _client((_) => _ok('{"status":"ok"}'), access: _pair);
      await c.delete(['https://www.youtube.com/watch?v=dQw4w9WgXcQ']);
      _expectAll(a.requests, carried: true);
    });

    test('fileExists, the one-byte range probe', () async {
      final (c, a) = _client((_) => _ok('x', status: 206), access: _pair);
      expect(await c.fileExists('clip.mp4'), isTrue);
      _expectAll(a.requests, carried: true);
      // The probe's own header must survive the merge with ours.
      expect(a.requests.single.headers['Range'], 'bytes=0-0');
    });

    test('fileExists asks the server, never a cache', () async {
      // Defect: Cloudflare kept the pulled clip at its edge and answered
      // 206 after the server had deleted it, so a server set up right was
      // reported as keeping deleted files.
      final (c, a) = _client((_) => _ok('x', status: 206), access: _pair);
      await c.fileExists('Kids/clip one.mp4');
      await c.fileExists('Kids/clip one.mp4');
      final first = a.requests[0].uri;
      final second = a.requests[1].uri;
      expect(first.path, '/download/Kids/clip%20one.mp4');
      expect(first.queryParameters['fresh'], isNotEmpty);
      expect(
        first.queryParameters['fresh'],
        isNot(second.queryParameters['fresh']),
      );
    });

    test('the pull keeps the plain, cacheable address', () async {
      final dir = await Directory.systemTemp.createTemp('mtf_cf_pull_');
      addTearDown(() => dir.delete(recursive: true));
      final (c, a) = _client((_) => _ok('x'), access: _pair);
      await c.downloadTo(
        'clip.mp4',
        '${dir.path}${Platform.pathSeparator}clip.mp4',
      );
      expect(a.requests.single.uri.query, isEmpty);
    });

    test('fetchText and the folder index', () async {
      final (c, a) = _client((_) => _ok('hello'), access: _pair);
      await c.fetchText('notes.txt');
      await c.fetchDownloadIndex();
      _expectAll(a.requests, carried: true);
    });

    test('the live channel: join, poll and the answers it posts', () async {
      final (c, a) = _client(_liveServer, access: _pair);
      await c.liveUpdates().toList();
      expect(a.requests.length, greaterThan(2));
      _expectAll(a.requests, carried: true);
    });

    test('downloadTo, the pull', () async {
      final dir = await Directory.systemTemp.createTemp('mtf_cf_');
      addTearDown(() => dir.delete(recursive: true));
      final (c, a) = _client((_) => _ok('MEDIA'), access: _pair);
      await c.downloadTo(
        'clip.mp4',
        '${dir.path}${Platform.pathSeparator}o.mp4',
      );
      _expectAll(a.requests, carried: true);
      // The pull's own keep-alive must survive the merge with ours.
      expect(a.requests.single.headers['Connection'], 'keep-alive');
    });

    test('streamingHeaders, which the players and probes copy', () {
      final (c, _) = _client((_) => _ok(''), access: _pair);
      expect(c.streamingHeaders[_idHeader], _id);
      expect(c.streamingHeaders[_secretHeader], _secret);
      expect(c.streamingHeaders['Connection'], 'keep-alive');
    });
  });

  group('beside Basic, never instead of it', () {
    test('both kinds of credentials are on the same request', () async {
      final (c, a) = _client(
        (_) => _ok('{"done":[],"queue":[]}'),
        username: 'family',
        password: 'pass',
        access: _pair,
      );
      await c.testConnection();
      final headers = a.requests.single.headers;
      expect(headers['Authorization'], startsWith('Basic '));
      expect(headers[_idHeader], _id);
      expect(headers[_secretHeader], _secret);
    });

    test('Basic is byte-for-byte what it was without the pair', () async {
      final (withPair, a) = _client(
        (_) => _ok('{"done":[],"queue":[]}'),
        username: 'family',
        password: 'pass',
        access: _pair,
      );
      final (without, b) = _client(
        (_) => _ok('{"done":[],"queue":[]}'),
        username: 'family',
        password: 'pass',
      );
      await withPair.testConnection();
      await without.testConnection();
      expect(
        a.requests.single.headers['Authorization'],
        b.requests.single.headers['Authorization'],
      );
      expect(
        withPair.streamingHeaders['Authorization'],
        without.streamingHeaders['Authorization'],
      );
    });
  });

  group('nothing is sent when the pair cannot be used', () {
    test(
      'no pair: no header on any request, streamingHeaders unchanged',
      () async {
        final (c, a) = _client((_) => _ok('{"done":[],"queue":[]}'));
        await c.testConnection();
        _expectAll(a.requests, carried: false);
        expect(c.streamingHeaders, {'Connection': 'keep-alive'});
      },
    );

    test('half a pair: neither header, not even the one that exists', () async {
      for (final half in [
        CloudflareAccess(clientId: _id, clientSecret: ''),
        CloudflareAccess(clientId: '', clientSecret: _secret),
      ]) {
        final (c, a) = _client(
          (_) => _ok('{"done":[],"queue":[]}'),
          access: half,
        );
        await c.testConnection();
        _expectAll(a.requests, carried: false);
        expect(c.streamingHeaders.containsKey(_idHeader), isFalse);
        expect(c.streamingHeaders.containsKey(_secretHeader), isFalse);
      }
    });

    // Defect prevented: Super's local address is a LAN http:// address that
    // is not behind Cloudflare. A saved pair must not be sent there, or the
    // secret crosses the home network in clear text.
    test('an http address: the secret is never sent in clear text', () async {
      final (c, a) = _client(
        (_) => _ok('{"done":[],"queue":[]}'),
        baseUrl: 'http://192.168.1.20:8081',
        access: _pair,
      );
      await c.testConnection();
      await c.fileExists('clip.mp4');
      _expectAll(a.requests, carried: false);
      expect(c.streamingHeaders.containsKey(_secretHeader), isFalse);
    });
  });

  group('the values never come back out in an error', () {
    // The apps write the text of an exception into the diagnostic
    // log, so an exception that quoted a header would put the secret there.
    void expectClean(Object error) {
      final text = '$error';
      expect(text, isNot(contains(_secret)));
      expect(text, isNot(contains(_id)));
      if (error is MTApiException) {
        expect(error.detail ?? '', isNot(contains(_secret)));
        expect(error.detail ?? '', isNot(contains(_id)));
      }
    }

    for (final status in [401, 403, 404, 500, 502]) {
      test('HTTP $status', () async {
        final (c, _) = _client(
          (_) => _ok('nope', status: status),
          access: _pair,
        );
        try {
          await c.testConnection();
          fail('expected a failure');
        } on MTApiException catch (e) {
          expectClean(e);
        }
      });
    }

    test('an error body from the server', () async {
      final (c, _) = _client(
        (_) => _ok('{"status":"error","msg":"boom"}'),
        access: _pair,
      );
      try {
        await c.add(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          Quality.best,
        );
        fail('expected a failure');
      } on MTApiException catch (e) {
        expectClean(e);
      }
    });

    test('a dropped connection', () async {
      final (c, _) = _client(
        (o) => throw DioException.connectionError(
          requestOptions: o,
          reason: 'refused',
        ),
        access: _pair,
      );
      try {
        await c.testConnection();
        fail('expected a failure');
      } on MTApiException catch (e) {
        expectClean(e);
      }
    });
  });
  group('who said no: Cloudflare Access or the server', () {
    // Measured on a real Service Auth application: a missing, wrong or
    // one-sided token earns a 403 HTML page marked with these two headers.
    ResponseBody accessPage(int status) => ResponseBody.fromString(
      '<title>Error ・ Cloudflare Access</title>Forbidden',
      status,
      headers: {
        Headers.contentTypeHeader: ['text/html'],
        'cf-access-domain': ['metube.example.com'],
        'cf-access-aud': ['4cb70fe7d9f16b51'],
      },
    );

    test('a 403 from Access is the token, not the password', () async {
      // Defect: it read as "wrong username or password", sending the
      // user to the one field that was fine.
      final (c, _) = _client((_) => accessPage(403), access: _pair);
      await expectLater(
        c.testConnection(),
        throwsA(isA<AccessRejectedException>()),
      );
    });

    test('with no token set at all it still names Access', () async {
      final (c, _) = _client((_) => accessPage(403));
      await expectLater(
        c.fetchHistory(),
        throwsA(isA<AccessRejectedException>()),
      );
    });

    test('a download refused by Access says so too', () async {
      final dir = await Directory.systemTemp.createTemp('mtf_cf_');
      addTearDown(() => dir.delete(recursive: true));
      final (c, _) = _client((_) => accessPage(403), access: _pair);
      await expectLater(
        c.downloadTo('clip.mp4', '${dir.path}${Platform.pathSeparator}c.mp4'),
        throwsA(isA<AccessRejectedException>()),
      );
    });

    test("the server's own 401 and 403 stay a password failure", () async {
      for (final status in [401, 403]) {
        final (c, _) = _client(
          (_) => _ok('unauthorized', status: status),
          access: _pair,
        );
        await expectLater(
          c.testConnection(),
          throwsA(
            allOf(
              isA<AuthFailureException>(),
              isNot(isA<AccessRejectedException>()),
            ),
          ),
        );
      }
    });

    test('Access is still a rejected credential to every caller', () {
      // The library's full-page error and the endpoint status catch the
      // parent type; a token refusal must not fall through to a stale list.
      expect(const AccessRejectedException(), isA<AuthFailureException>());
    });
  });
}
