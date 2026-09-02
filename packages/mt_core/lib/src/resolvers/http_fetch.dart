import 'dart:convert';
import 'dart:io';

/// جلب نصي بسيط للخدمات الخارجية (§4) — **معزول عن Dio العميل** حتى لا
/// تتسرب ترويسة Basic Auth الخاصة بالسيرفر إلى منصات خارجية.
typedef HttpGetString = Future<String> Function(Uri uri);

/// إرسال JSON للخدمات الخارجية — نفس العزل، ولنقطة InnerTube تحديداً.
typedef HttpPostJson = Future<String> Function(Uri uri, Object body);

/// متصفح سطح مكتب: يوتيوب وساوندكلاود يردّان صفحات مختلفة (أو يرفضان)
/// بحسب الوكيل، و`SOCS` يتخطى حاجز موافقة الكوكيز في أوروبا.
const _browserHeaders = {
  'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'accept-language': 'en-US,en;q=0.9',
};

/// التنفيذ الافتراضي بـ dart:io — مهلة قصيرة وفشل سريع؛ الـ resolvers
/// المستهلكة له كلها فشل-آمن (null عند أي مشكلة).
Future<String> ioHttpGetString(Uri uri) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(uri);
    _browserHeaders.forEach(request.headers.set);
    request.headers.set('cookie', 'SOCS=CAI');
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

Future<String> ioHttpPostJson(Uri uri, Object body) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.postUrl(uri);
    _browserHeaders.forEach(request.headers.set);
    request.headers.contentType = ContentType.json;
    request.write(json.encode(body));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}
