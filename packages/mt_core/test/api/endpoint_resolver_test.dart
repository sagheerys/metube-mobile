import 'dart:async';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('EndpointResolver', () {
    EndpointResolver makeResolver(Map<String, Future<bool> Function()> probes,
        {Duration timeout = const Duration(milliseconds: 200)}) {
      return EndpointResolver(
        probe: (url) => probes[url]?.call() ?? Future.value(false),
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
            localUrl: 'http://x', externalUrls: ['https://y']),
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
            localUrl: 'http://hangs', externalUrls: ['https://ok.example.com']),
        'https://ok.example.com',
      );
    });

    test('probe يرمي ⇒ false لا انهيار', () async {
      final resolver = makeResolver({
        'http://boom': () async => throw const NetworkException('down'),
      });
      expect(await resolver.probeAll(['http://boom']), {'http://boom': false});
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
      expect(result.values.every((v) => v), isTrue);
      expect(watch.elapsedMilliseconds, lessThan(200),
          reason: 'تسلسلي كان سيستغرق ≥240ms');
    });
  });
}
