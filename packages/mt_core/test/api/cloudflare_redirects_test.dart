import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// Redirects with a Cloudflare service token.
///
/// The platform's HTTP client re-sends custom headers to whatever host a
/// redirect names (measured), so without a guard the secret
/// would leave for a third party. Every case here says which defect it keeps
/// out.
const _id = '4c1f0d7a.access';
const _secret = '9a7e11c0b2d4f6a8';
const _idHeader = 'CF-Access-Client-Id';
const _secretHeader = 'CF-Access-Client-Secret';
const _home = 'https://metube.example.com';
const _other = 'https://evil.example.org';

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

ResponseBody _redirect(int status, String location) => ResponseBody.fromString(
  '',
  status,
  headers: {
    'location': [location],
  },
);

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

final _pair = CloudflareAccess(clientId: _id, clientSecret: _secret);

(MeTubeApiClient, _Recorder) _client(
  ResponseBody Function(RequestOptions) handler, {
  CloudflareAccess? access,
}) {
  final adapter = _Recorder(handler);
  final client = MeTubeApiClient(
    config: ServerConfig(baseUrl: _home, access: access),
    dio: Dio()..httpClientAdapter = adapter,
  );
  return (client, adapter);
}

bool _hasPair(RequestOptions r) =>
    r.headers.containsKey(_idHeader) || r.headers.containsKey(_secretHeader);

void main() {
  group('a redirect on the same server', () {
    test('is followed and keeps the headers (at most 8 hops)', () async {
      // Defect: a server that redirects `/history` to its own `/history/`
      // would break behind Access if the guard simply refused every 3xx.
      var calls = 0;
      final (c, a) = _client((o) {
        calls++;
        if (calls == 1) return _redirect(302, '$_home/history/');
        return _json('{"done":[],"queue":[]}');
      }, access: _pair);
      await c.fetchHistory();
      expect(a.requests, hasLength(2));
      expect(a.requests.last.uri.path, '/history/');
      for (final r in a.requests) {
        expect(r.headers[_idHeader], _id);
        expect(r.headers[_secretHeader], _secret);
      }
    });

    test('stops after MTConstants.maxRedirectHops', () async {
      // Defect: a redirect loop would spin for ever once we follow by hand.
      final (c, a) = _client(
        (o) => _redirect(302, '$_home/history'),
        access: _pair,
      );
      await expectLater(c.fetchHistory(), throwsA(isA<MTApiException>()));
      expect(a.requests, hasLength(1 + MTConstants.maxRedirectHops));
    });

    test('a relative Location is resolved against the request', () async {
      // Defect: a path-only Location sent to the adapter unresolved.
      var calls = 0;
      final (c, a) = _client((o) {
        calls++;
        if (calls == 1) return _redirect(301, '/history?limit=2');
        return _json('{"done":[],"queue":[]}');
      }, access: _pair);
      await c.fetchHistory();
      expect(a.requests.last.uri.host, 'metube.example.com');
      expect(a.requests.last.uri.path, '/history');
      expect(a.requests.last.uri.queryParameters['limit'], '2');
    });
  });

  group('a redirect to another host', () {
    test('is not followed and the other host never sees the pair', () async {
      // Defect: the secret travelling to a third party.
      final (c, a) = _client(
        (o) => o.uri.host == 'evil.example.org'
            ? _json('{"done":[],"queue":[]}')
            : _redirect(302, '$_other/history'),
        access: _pair,
      );
      await expectLater(c.fetchHistory(), throwsA(isA<MTApiException>()));
      expect(
        a.requests.where((r) => r.uri.host == 'evil.example.org'),
        isEmpty,
      );
      expect(
        a.requests.any((r) => r.uri.host != 'metube.example.com'),
        isFalse,
      );
    });

    test('also for the range probe in fileExists', () async {
      // Defect: the probe copied the pair to the CDN a file is parked on.
      final (c, a) = _client(
        (o) => _redirect(302, '$_other/clip.mp4'),
        access: _pair,
      );
      expect(await c.fileExists('clip.mp4'), isFalse);
      expect(a.requests, hasLength(1));
      expect(a.requests.any(_hasPairToOther), isFalse);
    });

    test('also for downloadTo', () async {
      // Defect: a pull following a redirect to another host with the pair.
      final dir = await Directory.systemTemp.createTemp('mtf_cfr_');
      addTearDown(() => dir.delete(recursive: true));
      final (c, a) = _client(
        (o) => _redirect(302, '$_other/clip.mp4'),
        access: _pair,
      );
      await expectLater(
        c.downloadTo('clip.mp4', '${dir.path}${Platform.pathSeparator}o.mp4'),
        throwsA(isA<MTApiException>()),
      );
      expect(
        a.requests.where((r) => r.uri.host == 'evil.example.org'),
        isEmpty,
      );
    });
  });

  group('the same-server redirect for the probe and the pull', () {
    test('fileExists follows and keeps Range and the pair', () async {
      // Defect: losing the one-byte Range on the second hop would pull the
      // whole file just to learn it exists.
      var calls = 0;
      final (c, a) = _client((o) {
        calls++;
        if (calls == 1) return _redirect(302, '$_home/other/clip.mp4');
        return ResponseBody.fromString('x', 206);
      }, access: _pair);
      expect(await c.fileExists('clip.mp4'), isTrue);
      expect(a.requests, hasLength(2));
      expect(a.requests.last.headers['Range'], 'bytes=0-0');
      expect(a.requests.last.headers[_idHeader], _id);
    });

    test('downloadTo follows and writes the file', () async {
      // Defect: a stream response that cannot be re-issued leaves an empty
      // file and a "success".
      final dir = await Directory.systemTemp.createTemp('mtf_cfr_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}o.mp4';
      var calls = 0;
      final (c, a) = _client((o) {
        calls++;
        if (calls == 1) return _redirect(302, '$_home/other/clip.mp4');
        return ResponseBody.fromString('MEDIA', 200);
      }, access: _pair);
      await c.downloadTo('clip.mp4', path);
      expect(await File(path).readAsString(), 'MEDIA');
      expect(a.requests.last.headers[_secretHeader], _secret);
    });
  });

  group('the request shape on a redirect', () {
    test('307 and 308 on a POST re-send the method and the body', () async {
      // Defect: a POST turned into a GET silently drops the download.
      for (final status in [307, 308]) {
        var calls = 0;
        final (c, a) = _client((o) {
          calls++;
          if (calls == 1) return _redirect(status, '$_home/add2');
          return _json('{"status":"ok"}');
        }, access: _pair);
        await c.add(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          Quality.best,
        );
        expect(a.requests, hasLength(2), reason: '$status');
        expect(a.requests.last.method, 'POST', reason: '$status');
        expect(a.requests.last.data, a.requests.first.data, reason: '$status');
        expect(a.requests.last.headers[_idHeader], _id, reason: '$status');
      }
    });

    test('307 on delete re-sends the same body', () async {
      var calls = 0;
      final (c, a) = _client((o) {
        calls++;
        if (calls == 1) return _redirect(307, '$_home/delete2');
        return _json('{"status":"ok"}');
      }, access: _pair);
      await c.delete(['https://www.youtube.com/watch?v=dQw4w9WgXcQ']);
      expect(a.requests.last.method, 'POST');
      expect(a.requests.last.data, a.requests.first.data);
    });

    test('301, 302 and 303 on a POST are not followed', () async {
      // Defect: browsers turn these into a GET without the body, which for
      // `add` would report success for a download that was never queued.
      for (final status in [301, 302, 303]) {
        final (c, a) = _client(
          (o) => _redirect(status, '$_home/add2'),
          access: _pair,
        );
        await expectLater(
          c.add('https://www.youtube.com/watch?v=dQw4w9WgXcQ', Quality.best),
          throwsA(isA<MTApiException>()),
          reason: '$status',
        );
        expect(a.requests, hasLength(1), reason: '$status');
      }
    });

    test('301, 302 and 303 on a GET are followed as a GET', () async {
      for (final status in [301, 302, 303]) {
        var calls = 0;
        final (c, a) = _client((o) {
          calls++;
          if (calls == 1) return _redirect(status, '$_home/history');
          return _json('{"done":[],"queue":[]}');
        }, access: _pair);
        await c.fetchHistory();
        expect(a.requests, hasLength(2), reason: '$status');
        expect(a.requests.last.method, 'GET', reason: '$status');
      }
    });
  });

  group('with no pair configured nothing changes', () {
    test('the redirect behaviour is the platform default', () async {
      // Defect: a guard that also changed the behaviour for people who are
      // not behind Access.
      final (c, a) = _client((o) => _redirect(302, '$_other/history'));
      await expectLater(c.fetchHistory(), throwsA(isA<MTApiException>()));
      expect(a.requests, hasLength(1));
      expect(a.requests.single.followRedirects, isTrue);
    });
  });
}

bool _hasPairToOther(RequestOptions r) =>
    r.uri.host != 'metube.example.com' && _hasPair(r);
