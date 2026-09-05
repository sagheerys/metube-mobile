import 'dart:async';

import '../constants/mt_constants.dart';
import 'api_exceptions.dart';
import 'metube_api_client.dart';

/// **نتيجة فحص رابط واحد.**
///
/// كانت `bool` — و«لا يستجيب» و«يرفض اعتمادك» شيئان مختلفان تماماً
/// للمستخدم: الأول يطارد راوتره، والثاني يصلحه بحقلين في الإعدادات.
/// (بلاغ المالك 2026-09-05: قفل السيرفر بكلاودفلير فصارت كل الروابط
/// حمراء بلا سبب معلن.)
enum MTEndpointStatus {
  /// سيرفر MeTube صالح يستجيب بالاعتماد الحالي.
  ok,

  /// 401/403 — الرابط حيّ لكن الاعتماد ناقص أو خاطئ.
  unauthorized,

  /// العنوان يستجيب لكنه **ليس MeTube**: صفحة HTML، أو JSON بلا
  /// `done`/`queue`، أو 404 على المسار. اعتماده يفشل بكل عملية بعده.
  notMeTube,

  /// انقطاع، مهلة، DNS، أو عنوان ليس عليه MeTube.
  unreachable;

  /// **الصالح للاعتماد النشط وحده هو `ok`**: رابط يردّ 401 لا يخدم
  /// شيئاً، فاعتماده يترك التطبيق ينزف أخطاءً بلا فائدة.
  bool get isUsable => this == MTEndpointStatus.ok;
}

/// دالة فحص وصول لرابط واحد.
typedef ProbeFn = Future<MTEndpointStatus> Function(String baseUrl);

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
          return MTEndpointStatus.ok;
        } on AuthFailureException {
          return MTEndpointStatus.unauthorized;
        } on NotMeTubeServerException {
          return MTEndpointStatus.notMeTube;
        } on NoApiException {
          // 404: خادم HTTP حيّ بلا واجهة MeTube — خطأ عنوان لا خطأ شبكة.
          return MTEndpointStatus.notMeTube;
        } on MTApiException {
          return MTEndpointStatus.unreachable;
        } finally {
          client.close();
        }
      },
    );
  }

  final ProbeFn _probe;
  final Duration probeTimeout;

  /// أول رابط **صالح** بترتيب الأفضلية: المحلي أولاً ثم الخارجية.
  /// null ⇔ لا شيء صالح.
  Future<String?> resolveActive({
    String? localUrl,
    List<String> externalUrls = const [],
  }) async =>
      (await resolveDetailed(localUrl: localUrl, externalUrls: externalUrls))
          .url;

  /// نفس الاختيار **ومعه حالة كل مرشح** من نفس جولة الفحص — حتى يقدر
  /// المتصل أن يقول *لماذا* لم يجد شيئاً بلا فحص ثانٍ.
  Future<({String? url, Map<String, MTEndpointStatus> statuses})>
      resolveDetailed({
    String? localUrl,
    List<String> externalUrls = const [],
  }) async {
    final candidates = [
      if (localUrl != null && localUrl.trim().isNotEmpty) localUrl,
      ...externalUrls.where((u) => u.trim().isNotEmpty),
    ];
    if (candidates.isEmpty) {
      return (url: null, statuses: const <String, MTEndpointStatus>{});
    }

    final statuses = await probeAll(candidates);
    for (final url in candidates) {
      if (statuses[url]?.isUsable ?? false) {
        return (url: url, statuses: statuses);
      }
    }
    return (url: null, statuses: statuses);
  }

  /// حالة كل رابط دفعة واحدة (نقاط الوصول الحية في شاشة الشبكة).
  Future<Map<String, MTEndpointStatus>> probeAll(List<String> urls) async {
    final entries = await Future.wait(urls.map((url) async {
      // try/catch حول await (لا onTimeout/catchError) حتى لا يكسرنا
      // مستقبل مُصنَّف Future<Never> من probe رامٍ.
      try {
        return MapEntry(url, await _probe(url).timeout(probeTimeout));
      } catch (_) {
        return MapEntry(url, MTEndpointStatus.unreachable);
      }
    }));
    return Map.fromEntries(entries);
  }
}
