import 'dart:async';

import '../constants/mt_constants.dart';
import 'api_exceptions.dart';
import 'metube_api_client.dart';

/// **The result of probing one endpoint.**
///
/// It used to be a `bool`, and "does not respond" versus "rejects your
/// credentials" are entirely different things to a user: the first sends
/// them hunting through their router, the second is fixed with two fields
/// in settings. (Field report 2026-09-05: the server was put behind
/// Cloudflare Access and every endpoint went red with no stated reason.)
enum MTEndpointStatus {
  /// A valid MeTube server that responds with the current credentials.
  ok,

  /// 401 or 403: the endpoint is alive, but the credentials are missing or
  /// wrong.
  unauthorized,

  /// The address responds but is **not MeTube**: an HTML page, JSON without
  /// `done`/`queue`, or a 404 on the path. Adopting it fails every
  /// operation
  /// afterwards.
  notMeTube,

  /// A drop, a timeout, DNS, or an address with no MeTube on it.
  unreachable;

  /// **Only `ok` may become the active endpoint**: one that answers 401
  /// serves nothing, and adopting it leaves the app bleeding errors to no
  /// purpose.
  bool get isUsable => this == MTEndpointStatus.ok;
}

/// A reachability probe for a single endpoint.
typedef ProbeFn = Future<MTEndpointStatus> Function(String baseUrl);

/// Choosing the active endpoint: the local one is preferred, then the
/// external ones in order. Probing runs **in parallel** with a short 4s
/// timeout, so a network change never hangs.
class EndpointResolver {
  EndpointResolver({
    required this._probe,
    this.probeTimeout = MTConstants.probeTimeout,
  });

  /// The practical constructor: probes with a real MeTube client using the
  /// same credentials for every endpoint.
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
          // 404: a live HTTP server with no MeTube interface. An address
          // mistake,
          // not a network one.
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

  /// The first **valid** endpoint in preference order: local first, then
  /// the
  /// external ones. `null` means nothing was valid.
  Future<String?> resolveActive({
    String? localUrl,
    List<String> externalUrls = const [],
  }) async =>
      (await resolveDetailed(localUrl: localUrl, externalUrls: externalUrls))
          .url;

  /// The same choice **together with the state of every candidate** from
  /// the
  /// same probing round, so the caller can say *why* it found nothing
  /// without probing twice.
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

  /// The state of every endpoint in one pass, for the live endpoint list in
  /// the network screen.
  Future<Map<String, MTEndpointStatus>> probeAll(List<String> urls) async {
    final entries = await Future.wait(urls.map((url) async {
      // try/catch around the await rather than onTimeout/catchError, so a
      // probe that throws cannot hand us a future typed `Future<Never>`.
      try {
        return MapEntry(url, await _probe(url).timeout(probeTimeout));
      } catch (_) {
        return MapEntry(url, MTEndpointStatus.unreachable);
      }
    }));
    return Map.fromEntries(entries);
  }
}
