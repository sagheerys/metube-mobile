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

    test('المحلي مفضّل حتى لو الخارجي يستجيب أيضاً', () async {
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
    });

    test('سقوط المحلي ⇒ أول خارجي مستجيب بترتيب القائمة', () async {
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

    test('لا شيء يستجيب ⇒ null', () async {
      final resolver = makeResolver({});
      expect(
        await resolver.resolveActive(
          localUrl: 'http://x',
          externalUrls: ['https://y'],
        ),
        isNull,
      );
    });

    test('probe معلّق يسقط بمهلة قصيرة بدل التعليق', () async {
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
    });

    test('probe يرمي ⇒ «لا يستجيب» لا انهيار', () async {
      final resolver = makeResolver({
        'http://boom': () async => throw const NetworkException('down'),
      });
      expect(await resolver.probeAll(['http://boom']), {
        'http://boom': MTEndpointStatus.unreachable,
      });
    });

    test('لا مرشحين ⇒ null فوراً', () async {
      final resolver = makeResolver({});
      expect(await resolver.resolveActive(localUrl: '  '), isNull);
    });

    test('probeAll يفحص بالتوازي (زمن ≈ الأبطأ لا المجموع)', () async {
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
    });
  });

  /// **A guard from field report 2026-09-05**: putting the server behind
  /// Cloudflare Access turned every endpoint "red" with no stated reason,
  /// and "does not respond" and "rejects your credentials" have entirely
  /// different cures.
  group('القفل ليس انقطاعاً', () {
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

    test('401 ⇒ unauthorized لا unreachable', () async {
      final resolver = clientResolver({'locked.example.com': 401});
      expect(await resolver.probeAll(['https://locked.example.com']), {
        'https://locked.example.com': MTEndpointStatus.unauthorized,
      });
    });

    test('رابط مرفوض الاعتماد لا يُعتمد نشطاً ويُتخطى لما بعده', () async {
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

    test('عنوان ليس MeTube ⇒ notMeTube لا unreachable', () async {
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
    });

    test('404 على المسار ⇒ notMeTube (خادم حيّ بلا واجهة MeTube)', () async {
      final resolver = clientResolver({'bare.example.com': 404});
      expect(await resolver.probeAll(['https://bare.example.com']), {
        'https://bare.example.com': MTEndpointStatus.notMeTube,
      });
    });

    test('عنوان ليس MeTube لا يُعتمد نشطاً', () async {
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

    test('كل الروابط مقفلة ⇒ null (ولا يُدّعى نجاح)', () async {
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
