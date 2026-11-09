import 'package:dio/dio.dart';

import '../constants/mt_constants.dart';
import 'image_headers.dart';
import 'metube_api_client.dart';

const _hopsKey = 'mtCfRedirectHops';

/// Keeps a Cloudflare service token on the server it was made for.
///
/// The platform's HTTP client re-sends custom headers to whatever host a
/// redirect names (measured), so with a pair configured we
/// stop it following redirects and follow them here instead, and only when
/// the target is the same origin as the server. A redirect we do not follow
/// is handed back as it came, and the caller classifies it like any other
/// unexpected status.
///
/// With no pair nothing is installed, so everyone else keeps the platform's
/// default behaviour.
void guardCloudflareRedirects(Dio dio, ServerConfig config) {
  if (config.accessHeaders.isEmpty) return;
  dio.options.followRedirects = false;
  dio.interceptors.add(_SameOriginRedirects(dio, config.baseUrl));
}

class _SameOriginRedirects extends Interceptor {
  _SameOriginRedirects(this._dio, this._baseUrl);

  final Dio _dio;
  final String _baseUrl;

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final next = _nextRequest(response);
    if (next == null) return handler.next(response);
    try {
      handler.resolve(await _dio.fetch<dynamic>(next));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  /// The request to send instead, or null when the response is to be
  /// returned as it is.
  RequestOptions? _nextRequest(Response response) {
    final status = response.statusCode ?? 0;
    if (status < 300 || status >= 400) return null;
    final location = response.headers.value('location');
    if (location == null) return null;

    final options = response.requestOptions;
    final hops = (options.extra[_hopsKey] as int? ?? 0) + 1;
    if (hops > MTConstants.maxRedirectHops) return null;

    final target = options.uri.resolve(location).toString();
    if (!sameOrigin(target, _baseUrl)) return null;

    final extra = {...options.extra, _hopsKey: hops};
    // 307 and 308 repeat the request exactly. 301, 302 and 303 turn a body
    // request into a GET without the body in a browser, which for `add`
    // would report a download that was never queued, so those are not
    // followed. A plain read is followed as a GET.
    if (status == 307 || status == 308) {
      return options.copyWith(
        path: target,
        queryParameters: <String, dynamic>{},
        extra: extra,
      );
    }
    if (options.data != null) return null;
    return options.copyWith(
      path: target,
      method: 'GET',
      queryParameters: <String, dynamic>{},
      extra: extra,
    );
  }
}
