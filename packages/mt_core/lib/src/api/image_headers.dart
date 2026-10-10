import 'metube_api_client.dart';

/// The headers an image request may carry.
///
/// **The server's password goes to the server and nowhere else.** Covers
/// were fetched with [MeTubeApiClient.streamingHeaders] whatever their
/// address, so a locked server's `Authorization` travelled with every
/// YouTube thumbnail to `i.ytimg.com`, and with every other platform's
/// cover to its CDN. An image on the server itself still gets them.
extension ImageHeaders on MeTubeApiClient {
  Map<String, String> imageHeadersFor(String url) =>
      sameOrigin(url, config.baseUrl) ? streamingHeaders : const {};
}

/// Whether [url] is on the server at [baseUrl]: the same scheme, host and
/// port, which a prefix test gets wrong (`:8086` is a prefix of `:80861`).
bool sameOrigin(String url, String baseUrl) {
  final a = Uri.tryParse(url);
  final b = Uri.tryParse(baseUrl);
  if (a == null || b == null || !a.hasAuthority || !b.hasAuthority) {
    return false;
  }
  return a.scheme == b.scheme &&
      a.host.toLowerCase() == b.host.toLowerCase() &&
      a.port == b.port;
}
