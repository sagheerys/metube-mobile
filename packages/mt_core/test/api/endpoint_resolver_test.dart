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
        // الفحص صار مصنفاً (ok/unauthorized/unreachable)؛ هذه الحالات
        // تعنى بالأفضلية والتوازي فيكفيها «يستجيب أو لا».
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
        'http://hangs': () => Completer<bool>().future, // لا يكتمل أبداً
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

  /// **حارس بلاغ المالك 2026-09-05**: قفل السيرفر خلف كلاودفلير فصار
  /// كل رابط «أحمر» بلا سبب معلن — و«لا يستجيب» و«يرفض اعتمادك»
  /// علاجان مختلفان تماماً.
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
      // 200 لكن الجسم HTML (خدمة أخرى على العنوان): «العنوان خطأ» علاجه
      // تصحيح العنوان، و«لا يستجيب» علاجه انتظار الشبكة — ولا يجوز
      // خلطهما في نقطة حمراء واحدة (قياس جهاز المالك 2026-09-06).
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

/// محوّل يعيد حالة HTTP واحدة — لفحص تصنيف الرفض دون شبكة.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status, {this.html = false});

  final int status;

  /// جسم HTML بحالة 200 — خدمة أخرى تعيش على العنوان.
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
