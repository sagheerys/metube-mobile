// بوابة 1: testConnection على السيرفر الحقيقي (المحلي والخارجي) +
// التقاط fixtures حقيقية من /history (خطوة 1.4).
// التشغيل: dart tool/gate1_capture.dart <localUrl> <externalUrl>
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
    final client =
        MeTubeApiClient(config: ServerConfig(baseUrl: url));
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

  // لقطة /history الحالية كما هي (fixture حقيقية "مكتمل")
  final history = await working.fetchHistory();
  print('history: done=${history.done.length} '
      'queue=${history.queue.length} pending=${history.pending.length}');

  // الخام للحفظ حرفياً
  final dio = working; // نلتقط الخام عبر طلب مباشر بنفس العميل
  final raw = await _rawHistory(working.config);
  const dir = 'test/fixtures/real';
  Directory(dir).createSync(recursive: true);
  File('$dir/history_real_done.json').writeAsStringSync(raw);
  print('حُفظت: $dir/history_real_done.json (${raw.length} بايت)');

  // فحص التحليل المتسامح على العينة الحقيقية
  for (final item in history.done.take(3)) {
    print('  عينة: url=${item.canonicalUrl.substring(0, 40)}… '
        'status=${item.rawStatus} filename=${item.filename != null}');
  }
  dio.close();
  exit(0);
}

Future<String> _rawHistory(ServerConfig config) async {
  final client = HttpClient();
  try {
    final request =
        await client.getUrl(Uri.parse('${config.baseUrl}/history'));
    final auth = config.basicAuthHeader;
    if (auth != null) request.headers.set('Authorization', auth);
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}
