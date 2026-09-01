import 'dart:async';

import '../constants/mt_constants.dart';
import 'api_exceptions.dart';
import 'metube_api_client.dart';

/// دالة فحص وصول لرابط واحد: true ⇔ سيرفر MeTube صالح يستجيب.
typedef ProbeFn = Future<bool> Function(String baseUrl);

/// اختيار الرابط النشط (م-28): محلي مفضّل ثم الروابط الخارجية بترتيبها —
/// الفحص **متوازٍ** بمهلة probe قصيرة (4s) حتى لا يعلّق تغيّر الشبكة.
class EndpointResolver {
  EndpointResolver({
    required this._probe,
    this.probeTimeout = MTConstants.probeTimeout,
  });

  /// المُنشئ العملي: يفحص بعميل MeTube حقيقي بنفس الاعتمادات لكل رابط.
  factory EndpointResolver.withClientFactory(
    MeTubeApiClient Function(String baseUrl) clientFactory,
  ) {
    return EndpointResolver(
      probe: (baseUrl) async {
        final client = clientFactory(baseUrl);
        try {
          await client.testConnection(timeout: MTConstants.probeTimeout);
          return true;
        } on MTApiException {
          return false;
        } finally {
          client.close();
        }
      },
    );
  }

  final ProbeFn _probe;
  final Duration probeTimeout;

  /// أول رابط يستجيب بترتيب الأفضلية: المحلي أولاً ثم الخارجية بترتيبها.
  /// null ⇔ لا شيء يستجيب.
  Future<String?> resolveActive({
    String? localUrl,
    List<String> externalUrls = const [],
  }) async {
    final candidates = [
      if (localUrl != null && localUrl.trim().isNotEmpty) localUrl,
      ...externalUrls.where((u) => u.trim().isNotEmpty),
    ];
    if (candidates.isEmpty) return null;

    final results = await probeAll(candidates);
    for (final url in candidates) {
      if (results[url] == true) return url;
    }
    return null;
  }

  /// حالة كل رابط دفعة واحدة (نقاط الوصول الحية في شاشة الشبكة).
  Future<Map<String, bool>> probeAll(List<String> urls) async {
    final entries = await Future.wait(urls.map((url) async {
      // try/catch حول await (لا onTimeout/catchError) حتى لا يكسرنا
      // مستقبل مُصنَّف Future<Never> من probe رامٍ.
      try {
        return MapEntry(url, await _probe(url).timeout(probeTimeout));
      } catch (_) {
        return MapEntry(url, false);
      }
    }));
    return Map.fromEntries(entries);
  }
}
