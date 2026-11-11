import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// A header value the platform refuses to send (a bad Client Secret).
///
/// **Measured** (Dart 3.13.7): a value holding a
/// non-ASCII character, an Arabic letter, a line break or NUL makes
/// `HttpClient` throw a `FormatException` whose text is "Invalid HTTP header
/// field value" followed by the value itself, which Dio wraps as a
/// `DioException` of type `unknown` with `message == null`. No request leaves
/// the device, and **the exception text contains the secret**. Pasting a
/// secret with a stray character is the most likely way for a person to get
/// this wrong, and without a translation they would read "cannot reach the
/// server".
const _id = '4c1f0d7a.access';

/// Behaves like the platform on a bad header value, and records what it
/// actually let through.
class _PlatformLikeAdapter implements HttpClientAdapter {
  final List<RequestOptions> sent = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    for (final value in options.headers.values) {
      final text = value.toString();
      if (text.codeUnits.any((c) => c > 126 || (c < 32 && c != 9))) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: FormatException('Invalid HTTP header field value: "$text"'),
        );
      }
    }
    sent.add(options);
    return ResponseBody.fromString(
      '{"done":[],"queue":[]}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(MeTubeApiClient, _PlatformLikeAdapter) _client(
  String secret, {
  bool pair = true,
}) {
  final adapter = _PlatformLikeAdapter();
  return (
    MeTubeApiClient(
      config: ServerConfig(
        baseUrl: 'https://metube.example.com',
        access: pair
            ? CloudflareAccess(clientId: _id, clientSecret: secret)
            : null,
      ),
      dio: Dio()..httpClientAdapter = adapter,
    ),
    adapter,
  );
}

void main() {
  // Each is a value that survives trimming, because trimming only touches
  // the ends.
  const badSecrets = {
    'an accented letter': 'abc\u00e9def',
    'an Arabic letter': 'abc\u0633def',
    'a line break inside': 'abc\r\ndef',
    'a lone newline inside': 'abc\ndef',
    'a NUL inside': 'abc\u0000def',
  };

  group('a Client Secret the platform refuses to send', () {
    badSecrets.forEach((name, secret) {
      test('$name: testConnection says Access rejected it', () async {
        final (client, adapter) = _client(secret);
        await expectLater(
          client.testConnection(),
          throwsA(isA<AccessRejectedException>()),
        );
        expect(adapter.sent, isEmpty, reason: 'nothing was sent');
      });
    });

    test('the other entry points say the same', () async {
      final (client, _) = _client('abc\u00e9def');
      await expectLater(
        client.fetchHistory(),
        throwsA(isA<AccessRejectedException>()),
      );
      await expectLater(
        client.add('https://www.youtube.com/watch?v=dQw4w9WgXcQ', Quality.best),
        throwsA(isA<AccessRejectedException>()),
      );
      await expectLater(
        client.fetchText('notes.txt'),
        throwsA(isA<AccessRejectedException>()),
      );
    });

    test('the pull says the same', () async {
      final (client, _) = _client('abc\u00e9def');
      await expectLater(
        client.downloadTo('clip.mp4', '${Uri.base.toFilePath()}never.bin'),
        throwsA(isA<AccessRejectedException>()),
      );
    });

    test('the message and the text never carry the secret', () async {
      // Defect: the platform's own message holds the value, and the apps
      // write exception text to the log.
      for (final secret in badSecrets.values) {
        final (client, _) = _client(secret);
        try {
          await client.testConnection();
          fail('expected a rejection');
        } on AccessRejectedException catch (e) {
          final text = '${e.detail} $e';
          expect(text, isNot(contains(secret)));
          expect(text, isNot(contains('def')));
          expect(text, isNot(contains('Invalid HTTP header')));
        }
      }
    });

    test('a rejection is not retried', () {
      expect(const AccessRejectedException().isRetryable, isFalse);
    });
  });

  group('with no pair the same failure is what it always was', () {
    test('a non-header failure stays a network failure', () async {
      // No pair set, no change: the translation is only for people who set one.
      final adapter = _PlatformLikeAdapter();
      final client = MeTubeApiClient(
        config: ServerConfig(baseUrl: 'https://metube.example.com'),
        dio: Dio()
          ..httpClientAdapter = _ThrowingAdapter(
            DioException(
              requestOptions: RequestOptions(path: '/history'),
              type: DioExceptionType.unknown,
              error: const FormatException(
                'Invalid HTTP header field value: "x"',
              ),
            ),
          ),
      );
      await expectLater(
        client.testConnection(),
        throwsA(isA<NetworkException>()),
      );
      expect(adapter.sent, isEmpty);
    });

    test('other failures with a pair stay network failures', () async {
      // Only the one measured shape is translated; a refused connection
      // must not be blamed on the token.
      final client = MeTubeApiClient(
        config: ServerConfig(
          baseUrl: 'https://metube.example.com',
          access: CloudflareAccess(clientId: _id, clientSecret: 'good'),
        ),
        dio: Dio()
          ..httpClientAdapter = _ThrowingAdapter(
            DioException(
              requestOptions: RequestOptions(path: '/history'),
              type: DioExceptionType.connectionError,
              error: const FormatException('Connection refused'),
            ),
          ),
      );
      await expectLater(
        client.testConnection(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.error);

  final DioException error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException(
    requestOptions: options,
    type: error.type,
    error: error.error,
  );

  @override
  void close({bool force = false}) {}
}
