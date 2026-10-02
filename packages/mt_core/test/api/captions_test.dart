import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **Subtitles alone, and reading them back** (§2.2, measured on a real
/// server 2026-09-29).
void main() {
  late List<RequestOptions> requests;

  MeTubeApiClient client(ResponseBody Function(RequestOptions) handler) {
    requests = [];
    final dio = Dio()..httpClientAdapter = _Adapter(handler, requests);
    return MeTubeApiClient(
      config: ServerConfig(baseUrl: 'https://metube.example.com'),
      dio: dio,
    );
  }

  ResponseBody ok() => ResponseBody.fromString(
    '{"status": "ok"}',
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  test(
    'asks for the subtitles alone, with the fields the server requires',
    () async {
      final api = client((_) => ok());
      await api.addCaptions(
        'https://www.youtube.com/watch?v=jNQXAC9IVRw',
        language: 'ar',
      );

      final body = jsonDecode(requests.single.data as String) as Map;
      expect(requests.single.path, 'https://metube.example.com/add');
      expect(body, {
        'url': 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
        'download_type': 'captions',
        'format': 'srt',
        'quality': 'best',
        'subtitle_language': 'ar',
        'subtitle_mode': 'prefer_manual',
      });
    },
  );

  test('a refusal from the server is reported, not swallowed', () async {
    final api = client(
      (_) => ResponseBody.fromString(
        '{"status": "error", "msg": "bad language"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
    expect(
      api.addCaptions('https://youtu.be/x', language: 'en'),
      throwsA(isA<MTApiException>()),
    );
  });

  group('fetchText', () {
    ResponseBody bytes(List<int> data, {int status = 200}) =>
        ResponseBody.fromBytes(data, status);

    test('reads an Arabic subtitle file as UTF-8', () async {
      const srt = '1\n00:00:01,000 --> 00:00:02,000\nمرحباً\n';
      final api = client((_) => bytes(utf8.encode(srt)));

      expect(await api.fetchText('clip.ar.srt'), srt);
      expect(requests.single.path, contains('/download/clip.ar.srt'));
    });

    test('refuses a file too large to be a transcript', () async {
      final api = client((_) => bytes(List.filled(11, 65)));
      expect(
        api.fetchText('movie.mp4', maxBytes: 10),
        throwsA(isA<ServerErrorException>()),
      );
    });

    test('never builds a URL for an unsafe filename', () async {
      final api = client((_) => bytes(const []));
      expect(
        api.fetchText('../secret.srt'),
        throwsA(isA<UnsafeFilenameException>()),
      );
      expect(requests, isEmpty);
    });

    test('a missing file is a 404, not an empty transcript', () async {
      final api = client((_) => bytes(const [], status: 404));
      expect(api.fetchText('gone.srt'), throwsA(isA<NoApiException>()));
    });
  });

  test('withoutCaptions keeps every clip and drops only subtitles jobs', () {
    final history = HistoryResponse.fromJson({
      'done': [
        {'url': 'a', 'download_type': 'video'},
        {'url': 'b', 'download_type': 'captions'},
        {'url': 'c'},
      ],
      'queue': [
        {'url': 'd', 'download_type': 'captions'},
      ],
      'pending': [
        {'url': 'e', 'download_type': 'audio'},
      ],
    }).withoutCaptions();

    expect(history.done.map((i) => i.canonicalUrl), ['a', 'c']);
    expect(history.queue, isEmpty);
    expect(history.pending.single.canonicalUrl, 'e');
  });

  group('HistoryItem.downloadType', () {
    test('a subtitles job is recognised from the real server row', () {
      final item = HistoryItem.fromJson({
        'url': 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
        'download_type': 'captions',
        'format': 'srt',
        'status': 'finished',
        'filename': 'Me at the zoo [jNQXAC9IVRw].en.srt',
        'size': 416,
      });
      expect(item.isCaptions, isTrue);
      expect(item.downloadType, 'captions');
    });

    test('a video, and a row from a server too old to say, are not', () {
      expect(
        HistoryItem.fromJson({'url': 'u', 'download_type': 'video'}).isCaptions,
        isFalse,
      );
      expect(HistoryItem.fromJson({'url': 'u'}).isCaptions, isFalse);
    });
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler, this.requests);

  final ResponseBody Function(RequestOptions) handler;
  final List<RequestOptions> requests;

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
