import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// A scripted Engine.IO server: each long-poll gets the next reply.
class _Server implements HttpClientAdapter {
  _Server(this.polls);

  final List<String> polls;
  final posts = <String>[];
  final queries = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    queries.add(options.queryParameters);
    if (options.method == 'POST') {
      posts.add(options.data as String);
      return ResponseBody.fromString('ok', 200);
    }
    if (!options.queryParameters.containsKey('sid')) {
      return ResponseBody.fromString(
        '0{"sid":"s1","pingInterval":25000,"pingTimeout":20000}',
        200,
      );
    }
    return ResponseBody.fromString(
      polls.isEmpty ? '1' : polls.removeAt(0),
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('the live channel joins, answers the ping, and reports changes '
      'until the server closes it', () async {
    final item = {
      'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      'status': 'downloading',
      'percent': 50,
    };
    final server = _Server([
      // The whole history on joining is skipped; the ping is answered.
      '40{"sid":"n1"}\x1e42["all",[[],[]]]\x1e2',
      '42${jsonEncode(['updated', jsonEncode(item)])}',
      '42${jsonEncode([
        'completed',
        {...item, 'status': 'finished'},
      ])}',
    ]);
    final client = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'https://metube.example.com'),
      dio: Dio()..httpClientAdapter = server,
    );

    final updates = await client.liveUpdates().toList();

    expect(updates.map((u) => u.completed), [false, true]);
    expect(updates.first.item.progress, 0.5);
    expect(server.posts, ['40', '3']);
    expect(server.queries.last['sid'], 's1');
  });

  test('a server without the channel ends it quietly', () async {
    final client = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'https://metube.example.com'),
      dio: Dio()..httpClientAdapter = _NotFound(),
    );
    expect(await client.liveUpdates().toList(), isEmpty);
  });
}

class _NotFound implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('not found', 404);

  @override
  void close({bool force = false}) {}
}
