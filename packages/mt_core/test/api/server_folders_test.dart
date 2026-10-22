import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// The live channel as MeTube 2026.10.09 speaks it (measured): a
/// handshake, then on joining, the events every client gets, the folder
/// list last. There is no HTTP endpoint for that list.
class _Socket implements HttpClientAdapter {
  _Socket(this.events);

  final String events;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'POST') return ResponseBody.fromString('ok', 200);
    if (!options.queryParameters.containsKey('sid')) {
      return ResponseBody.fromString('0{"sid":"s1","pingInterval":25000}', 200);
    }
    return ResponseBody.fromString(events, 200);
  }

  @override
  void close({bool force = false}) {}
}

MeTubeApiClient _client(_Socket socket) => MeTubeApiClient(
  config: ServerConfig(baseUrl: 'https://srv.example.com'),
  dio: Dio()..httpClientAdapter = socket,
);

void main() {
  test('the folder list is read from the live channel, top left out', () async {
    final socket = _Socket(
      '40{"sid":"x"}\x1e42["all","[[],[]]"]\x1e'
      '42["configuration","{\\"CUSTOM_DIRS\\": true}"]\x1e'
      '42["custom_dirs","{\\"download_dir\\": [\\"\\", \\"Quran\\", \\"Ai\\", '
      '\\"Ai/Lessons\\"], \\"audio_download_dir\\": [\\"\\", \\"Music\\"]}"]',
    );
    final folders = await _client(socket).fetchFolders();
    expect(folders!.enabled, isTrue);
    expect(folders.video, ['Ai', 'Ai/Lessons', 'Quran']);
    expect(folders.of(audio: true), ['Music']);
    // The session is closed on the way out, not left for the server to
    // time out.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(socket.requests.map((r) => r.data), contains('1'));
  });

  test('a server with CUSTOM_DIRS off says so', () async {
    final socket = _Socket('42["configuration",{"CUSTOM_DIRS": false}]');
    final folders = await _client(socket).fetchFolders();
    expect(folders!.enabled, isFalse);
  });

  test('a server that never says gives null, not an empty list', () async {
    final socket = _Socket('not a socket');
    expect(
      await _client(socket).fetchFolders(timeout: const Duration(seconds: 1)),
      isNull,
    );
  });

  test('cleaning a folder keeps nesting and drops what the server refuses', () {
    expect(ServerPath.cleanFolder(' Ai / Lessons/ '), 'Ai/Lessons');
    expect(ServerPath.cleanFolder(r'Ai\Lessons'), 'Ai/Lessons');
    expect(ServerPath.cleanFolder('../../etc'), 'etc');
    expect(ServerPath.cleanFolder(' . '), '');
  });
}
