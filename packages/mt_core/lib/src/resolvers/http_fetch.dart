import 'dart:convert';
import 'dart:io';

/// جلب نصي بسيط للخدمات الخارجية (§4) — **معزول عن Dio العميل** حتى لا
/// تتسرب ترويسة Basic Auth الخاصة بالسيرفر إلى منصات خارجية.
typedef HttpGetString = Future<String> Function(Uri uri);

/// التنفيذ الافتراضي بـ dart:io — مهلة قصيرة وفشل سريع؛ الـ resolvers
/// المستهلكة له كلها فشل-آمن (null عند أي مشكلة).
Future<String> ioHttpGetString(Uri uri) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(uri);
    request.followRedirects = true;
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}
