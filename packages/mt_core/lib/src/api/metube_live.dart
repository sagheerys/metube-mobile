part of 'metube_api_client.dart';

/// **MeTube's live channel, read the way a browser without WebSockets
/// reads it**: Engine.IO 4 long-polling over plain HTTP, through the same
/// client, credentials and tunnel as every other request.
///
/// `/history` is read every few seconds and is the size of the whole
/// server, so a short clip went from nothing to done between two reads,
/// and a long one moved in jumps. The live channel reports every step of
/// yt-dlp's progress as it happens.
///
/// It is a bonus, never a dependency: anything unexpected (an older server,
/// a proxy that refuses the path, a dropped connection) ends the stream
/// quietly, and polling carries on alone.
Stream<MTLiveUpdate> _liveUpdates(MeTubeApiClient client) {
  final cancel = CancelToken();
  late final StreamController<MTLiveUpdate> out;
  final endpoint = '${client.config.baseUrl}/socket.io/';
  final text = Options(
    responseType: ResponseType.plain,
    contentType: 'text/plain;charset=UTF-8',
    // Long enough to outlast the server's ping interval, so a quiet
    // channel is a held request rather than a timeout.
    receiveTimeout: const Duration(seconds: 60),
  );

  Future<String> send(Map<String, String> query, String packet) async {
    final response = await client._dio.post<String>(
      endpoint,
      queryParameters: query,
      data: packet,
      options: text,
      cancelToken: cancel,
    );
    return response.data ?? '';
  }

  Future<void> run() async {
    try {
      final hello = await client._dio.get<String>(
        endpoint,
        queryParameters: const {'EIO': '4', 'transport': 'polling'},
        options: text,
        cancelToken: cancel,
      );
      final open = hello.data ?? '';
      if (hello.statusCode != 200 || !open.startsWith('0')) return;
      final sid = (jsonDecode(open.substring(1)) as Map)['sid'];
      if (sid is! String) return;
      final query = {'EIO': '4', 'transport': 'polling', 'sid': sid};
      // Joins the default namespace, where MeTube emits.
      await send(query, '40');
      while (!cancel.isCancelled) {
        final response = await client._dio.get<String>(
          endpoint,
          queryParameters: query,
          options: text,
          cancelToken: cancel,
        );
        if (response.statusCode != 200) return;
        for (final packet in (response.data ?? '').split('\x1e')) {
          // The server's ping; unanswered, it closes the session.
          if (packet == '2') {
            await send(query, '3');
          } else if (packet.startsWith('1')) {
            return;
          } else if (MTLiveUpdate.fromPacket(packet) case final update?) {
            if (!out.isClosed) out.add(update);
          }
        }
      }
    } on Object {
      // Polling carries on without it.
    } finally {
      await out.close();
    }
  }

  out = StreamController<MTLiveUpdate>(
    onListen: () => unawaited(run()),
    onCancel: () => cancel.cancel(),
  );
  return out.stream;
}
