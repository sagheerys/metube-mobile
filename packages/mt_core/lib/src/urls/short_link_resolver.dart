import 'dart:io';

import '../constants/mt_constants.dart';
import 'url_kit.dart';

/// One step of redirect following: returns the next `Location` URL, or
/// null when there is no redirect. Injected for testing; the default
/// implementation is [ioRedirectStep].
typedef RedirectStep = Future<String?> Function(String url);

/// Resolves short links (vm./vt.tiktok, fb.watch, facebook /share/,
/// on.soundcloud) by following redirects, while **refusing an HTTPS to HTTP
/// downgrade** (`05-DATA-SCHEMA.md` §4). On any failure or downgrade the
/// original URL is returned unchanged.
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
      return url; // resolution failed, so the original URL goes to the server unchanged.
    }

    final resolvedIsHttps = current.toLowerCase().startsWith('https://');
    if (origIsHttps && !resolvedIsHttps) return url;
    return current;
  }

  /// **Resolution with a time ceiling, for the routing decision before
  /// downloading** (field report 2026-09-08).
  ///
  /// `on.soundcloud.com/…`, which is what the share button in the
  /// SoundCloud app produces, contains no `/sets/`, so `PlaylistDetector`
  /// saw a single clip and passed it to the server, where yt-dlp expanded
  /// it into a **whole album**: twenty tracks downloaded with no selection
  /// screen, while the app knew of one task. The decision has to be made on
  /// the **final** URL, not the entered one.
  ///
  /// The ceiling is necessary: this decision happens while the user waits,
  /// unlike resolution inside the engine, which runs after the task has
  /// already started.
  Future<String> resolveForRouting(String url) =>
      resolve(url)
          .timeout(MTConstants.routingResolveTimeout, onTimeout: () => url);
}

/// The default dart:io implementation: a GET with no automatic following,
/// reading the Location header only and closing the response without
/// pulling the body.
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
