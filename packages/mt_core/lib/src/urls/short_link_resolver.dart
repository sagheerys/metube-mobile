import 'dart:io';

import '../constants/mt_constants.dart';
import 'url_kit.dart';

/// خطوة واحدة من تتبع redirect: تعيد رابط `Location` التالي أو null
/// إن لم يكن هناك تحويل. تُحقن للاختبار — التنفيذ الافتراضي [ioRedirectStep].
typedef RedirectStep = Future<String?> Function(String url);

/// حلّ الروابط القصيرة (vm./vt.tiktok، fb.watch، facebook /share/،
/// on.soundcloud) بتتبع redirect — مع **منع الهبوط HTTPS→HTTP**
/// (`05-DATA-SCHEMA.md` §4): عند أي فشل أو هبوط يُعاد الرابط الأصلي كما هو.
class ShortLinkResolver {
  ShortLinkResolver({RedirectStep? redirectStep})
      : _redirectStep = redirectStep ?? ioRedirectStep;

  final RedirectStep _redirectStep;

  Future<String> resolve(String url) async {
    if (!UrlKit.needsResolution(url)) return url;

    final origIsHttps = url.toLowerCase().startsWith('https://');
    var current = url;
    try {
      for (var hop = 0; hop < MTConstants.maxRedirectHops; hop++) {
        final next = await _redirectStep(current);
        if (next == null) break;
        current = Uri.parse(current).resolve(next).toString();
      }
    } catch (_) {
      return url; // فشل الحل ⇒ الرابط الأصلي يُمرَّر للسيرفر كما هو.
    }

    final resolvedIsHttps = current.toLowerCase().startsWith('https://');
    if (origIsHttps && !resolvedIsHttps) return url;
    return current;
  }

  /// **حلٌّ بسقف زمني، لقرار التوجيه قبل التنزيل** (بلاغ المالك
  /// 2026-09-08).
  ///
  /// `on.soundcloud.com/…` — وهو ما يعطيه زرّ المشاركة في تطبيق
  /// ساوندكلاود — لا يحوي `/sets/`، فكان `PlaylistDetector` يراه مقطعاً
  /// مفرداً ويمرّره للسيرفر، فيفكّه yt-dlp هناك إلى **ألبوم كامل**:
  /// عشرون مقطعاً نزلت بلا شاشة اختيار، والتطبيق لا يعرف إلا مهمة
  /// واحدة. القرار يجب أن يقع على الرابط **النهائي** لا المُدخل.
  ///
  /// والسقف ضروري: القرار هنا يقع والمستخدم ينتظر — بخلاف الحلّ داخل
  /// المحرك الذي يجري بعد أن بدأت المهمة.
  Future<String> resolveForRouting(String url) => resolve(url)
      .timeout(MTConstants.routingResolveTimeout, onTimeout: () => url);
}

/// التنفيذ الافتراضي بـ dart:io — طلب GET بلا تتبع تلقائي، يقرأ ترويسة
/// Location فقط ويغلق الاستجابة (لا يسحب الجسم).
Future<String?> ioRedirectStep(String url) async {
  final client = HttpClient()
    ..connectionTimeout = MTConstants.testConnectionTimeout;
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.followRedirects = false;
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode >= 300 && response.statusCode < 400) {
      return response.headers.value(HttpHeaders.locationHeader);
    }
    return null;
  } finally {
    client.close(force: true);
  }
}
