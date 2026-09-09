import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('EndpointResolver', () {
    EndpointResolver makeResolver(
      Map<String, Future<bool> Function()> probes, {
      Duration timeout = const Duration(milliseconds: 200),
    }) {
      return EndpointResolver(
        // Probing is now classified (ok / unauthorized / unreachable);
        // these cases are about preference and parallelism, so "responds or
        // not" is enough for them.
        probe: (url) async => await (probes[url]?.call() ?? Future.value(false))
            ? MTEndpointStatus.ok
            : MTEndpointStatus.unreachable,
        probeTimeout: timeout,
      );
    }

    test(
      'the local URL is preferred even when the external one also responds',
      () async {
        final resolver = makeResolver({
          'http://192.168.1.10:8081': () async => true,
          'https://tunnel.example.com': () async => true,
        });
        expect(
          await resolver.resolveActive(
            localUrl: 'http://192.168.1.10:8081',
            externalUrls: ['https://tunnel.example.com'],
          ),
          'http://192.168.1.10:8081',
        );
      },
    );

    test('when the local URL drops, the first responding external one in list order', () async {
      final resolver = makeResolver({
        'http://192.168.1.10:8081': () async => false,
        'https://a.example.com': () async => false,
        'https://b.example.com': () async => true,
      });
      expect(
        await resolver.resolveActive(
          localUrl: 'http://192.168.1.10:8081',
          externalUrls: ['https://a.example.com', 'https://b.example.com'],
        ),
        'https://b.example.com',
      );
    });

    test('nothing responds gives null', () async {
      final resolver = makeResolver({});
      expect(
        await resolver.resolveActive(
          localUrl: 'http://x',
          externalUrls: ['https://y'],
        ),
        isNull,
      );
    });

    test(
      'a hanging probe fails on a short timeout instead of hanging',
      () async {
        final resolver = makeResolver({
          'http://hangs': () => Completer<bool>().future, // never completes
          'https://ok.example.com': () async => true,
        });
        expect(
          await resolver.resolveActive(
            localUrl: 'http://hangs',
            externalUrls: ['https://ok.example.com'],
          ),
          'https://ok.example.com',
        );
      },
    );

    test('a probe that throws means unreachable, not a crash', () async {
      final resolver = makeResolver({
        'http://boom': () async => throw const NetworkException('down'),
      });
      expect(await resolver.probeAll(['http://boom']), {
        'http://boom': MTEndpointStatus.unreachable,
      });
    });

    test('no candidates gives null immediately', () async {
      final resolver = makeResolver({});
      expect(await resolver.resolveActive(localUrl: '  '), isNull);
    });

    test(
      'probeAll runs in parallel: the time is the slowest, not the sum',
      () async {
        Future<bool> Function() slowTrue() =>
            () => Future.delayed(const Duration(milliseconds: 80), () => true);
        final resolver = makeResolver({
          'a': slowTrue(),
          'b': slowTrue(),
          'c': slowTrue(),
        });
        final watch = Stopwatch()..start();
        final result = await resolver.probeAll(['a', 'b', 'c']);
        watch.stop();
        expect(result.values.every((v) => v.isUsable), isTrue);
        expect(
          watch.elapsedMilliseconds,
          lessThan(200),
          reason: 'تسلسلي كان سيستغرق ≥240ms',
        );
      },
    );
  });

  /// **A guard from field report 2026-09-05**: putting the server behind
  /// Cloudflare Access turned every endpoint "red" with no stated reason,
  /// and "does not respond" and "rejects your credentials" have entirely
  /// different cures.
  group('a locked door is not a broken road', () {
    EndpointResolver clientResolver(
      Map<String, int> statusByHost, {
      Set<String> html = const {},
    }) {
      return EndpointResolver.withClientFactory((baseUrl) {
        final host = Uri.parse(baseUrl).host;
        final dio = Dio()
          ..httpClientAdapter = _StatusAdapter(
            statusByHost[host] ?? 200,
            html: html.contains(host),
          );
        return MeTubeApiClient(
          config: ServerConfig(baseUrl: baseUrl, username: 'u', password: 'p'),
          dio: dio,
        );
      });
    }

    test('401 is unauthorized, not unreachable', () async {
      final resolver = clientResolver({'locked.example.com': 401});
      expect(await resolver.probeAll(['https://locked.example.com']), {
        'https://locked.example.com': MTEndpointStatus.unauthorized,
      });
    });

    test('a URL that refuses the credentials is not adopted, and the next is tried', () async {
      final resolver = clientResolver({'locked.example.com': 401});
      expect(
        await resolver.resolveActive(
          localUrl: 'https://locked.example.com',
          externalUrls: ['https://open.example.com'],
        ),
        'https://open.example.com',
        reason: 'رابط يردّ 401 لا يخدم شيئاً — اعتماده ينزف أخطاءً',
      );
    });

    test(
      'an address that is not MeTube is notMeTube, not unreachable',
      () async {
        // A 200 with an HTML body means another service lives at that
        // address. "Wrong address" is cured by correcting the address and
        // "does not respond" by waiting for the network, and the two must not
        // be conflated into one red dot (measured on a real device
        // 2026-09-06).
        final resolver = clientResolver(
          {'wrong.example.com': 200},
          html: {'wrong.example.com'},
        );
        expect(await resolver.probeAll(['https://wrong.example.com']), {
          'https://wrong.example.com': MTEndpointStatus.notMeTube,
        });
      },
    );

    test(
      '404 on the path is notMeTube: a live server with no MeTube API',
      () async {
        final resolver = clientResolver({'bare.example.com': 404});
        expect(await resolver.probeAll(['https://bare.example.com']), {
          'https://bare.example.com': MTEndpointStatus.notMeTube,
        });
      },
    );

    test('an address that is not MeTube is never adopted as active', () async {
      final resolver = clientResolver(
        {'wrong.example.com': 200},
        html: {'wrong.example.com'},
      );
      expect(
        await resolver.resolveActive(
          localUrl: 'https://wrong.example.com',
          externalUrls: ['https://open.example.com'],
        ),
        'https://open.example.com',
      );
    });

    test('every URL locked gives null, and no success is claimed', () async {
      final resolver = clientResolver({
        'a.example.com': 401,
        'b.example.com': 403,
      });
      expect(
        await resolver.resolveActive(
          localUrl: 'https://a.example.com',
          externalUrls: ['https://b.example.com'],
        ),
        isNull,
      );
    });
  });
}

/// An adapter returning one HTTP status, to test refusal classification
/// without a network.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status, {this.html = false});

  final int status;

  /// An HTML body with status 200: another service living at the address.
  final bool html;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = switch ((status, html)) {
      (200, true) => '<html><body>TrueNAS</body></html>',
      (200, false) => '{"done":[],"queue":[]}',
      _ => 'denied',
    };
    return ResponseBody.fromBytes(
      utf8.encode(body),
      status,
      headers: {
        't': [status == 200 && !html ? 'application/json' : 'text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
