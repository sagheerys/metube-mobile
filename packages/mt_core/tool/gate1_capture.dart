// Gate 1: testConnection against a real server, local and external, plus
// capturing real fixtures from /history (step 1.4).
// Usage: dart tool/gate1_capture.dart <localUrl> <externalUrl>
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:mt_core/mt_core.dart';

Future<void> main(List<String> args) async {
  final urls = args.isEmpty
      ? ['http://192.168.1.10:8086', 'https://metube.example.com']
      : args;

  MeTubeApiClient? working;
  for (final url in urls) {
    final client = MeTubeApiClient(config: ServerConfig(baseUrl: url));
    final watch = Stopwatch()..start();
    try {
      await client.testConnection();
      print('OK  testConnection: $url (${watch.elapsedMilliseconds}ms)');
      working ??= client;
      if (working != client) client.close();
    } on MTApiException catch (e) {
      print('FAIL testConnection: $url → ${e.runtimeType}: ${e.detail}');
      client.close();
    }
  }
  if (working == null) {
    print('لا رابط يستجيب — توقف.');
    exit(1);
  }

  // The current /history snapshot as it is: a real "completed" fixture.
  final history = await working.fetchHistory();
  print(
    'history: done=${history.done.length} '
    'queue=${history.queue.length} pending=${history.pending.length}',
  );

  // The raw body, saved verbatim.
  final dio = working; // capture the raw body with a direct request through the same client
  final raw = await _rawHistory(working.config);
  const dir = 'test/fixtures/real';
  Directory(dir).createSync(recursive: true);
  File('$dir/history_real_done.json').writeAsStringSync(raw);
  print('حُفظت: $dir/history_real_done.json (${raw.length} بايت)');

  // Checks tolerant parsing against the real sample.
  for (final item in history.done.take(3)) {
    print(
      '  عينة: url=${item.canonicalUrl.substring(0, 40)}… '
      'status=${item.rawStatus} filename=${item.filename != null}',
    );
  }
  dio.close();
  exit(0);
}

Future<String> _rawHistory(ServerConfig config) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('${config.baseUrl}/history'));
    final auth = config.basicAuthHeader;
    if (auth != null) request.headers.set('Authorization', auth);
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}
