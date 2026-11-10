import 'dart:convert';

import 'cloudflare_access.dart';

/// Connection settings for a MeTube server. The URL is normalised by
/// stripping trailing slashes.
class ServerConfig {
  /// An address typed as `https://user:pass@host` gives its user and
  /// password to the two fields (where those are empty) and keeps only the
  /// address: left inside it, the password was stored as plain settings,
  /// shown in the settings summary and copied to backups.
  factory ServerConfig({
    required String baseUrl,
    String? username,
    String? password,
    CloudflareAccess? access,
  }) {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || uri.userInfo.isEmpty || !uri.hasScheme) {
      return ServerConfig._(baseUrl, username, password, access);
    }
    final info = uri.userInfo;
    final colon = info.indexOf(':');
    String? part(String s) {
      if (s.isEmpty) return null;
      try {
        return Uri.decodeComponent(s);
      } on ArgumentError {
        return s;
      }
    }

    String? typed(String? field, String? fromUrl) =>
        (field?.isNotEmpty ?? false) ? field : (fromUrl ?? field);
    return ServerConfig._(
      uri.replace(userInfo: '').toString(),
      typed(username, part(colon < 0 ? info : info.substring(0, colon))),
      typed(password, colon < 0 ? null : part(info.substring(colon + 1))),
      access,
    );
  }

  ServerConfig._(String baseUrl, this.username, this.password, this.access)
    : baseUrl = normalizeBaseUrl(baseUrl);

  final String baseUrl;
  final String? username;
  final String? password;

  /// The optional Cloudflare Access service token. `null` for everyone who
  /// does not sit behind Access, which keeps this config equal to what it
  /// was before the field existed.
  final CloudflareAccess? access;

  /// The two Cloudflare headers for [baseUrl], or nothing (no pair, a
  /// one-sided pair, or an address that is not https).
  Map<String, String> get accessHeaders =>
      access?.headersFor(baseUrl) ?? const {};

  /// The same account at another of the server's addresses. Every field
  /// travels, so an address switch can never drop the password or the
  /// Cloudflare pair; the https rule still decides what [url] receives.
  ServerConfig at(String url) => ServerConfig(
    baseUrl: url,
    username: username,
    password: password,
    access: access,
  );

  /// A server address as a settings line shows it: `host:port`, never the
  /// `user:pass@` an address typed by hand may carry (which `authority`
  /// keeps). Anything that does not parse is shown as it is.
  static String hostLabel(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return url;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  static String normalizeBaseUrl(String raw) =>
      raw.trim().replaceFirst(RegExp(r'/+$'), '');

  bool get hasCredentials =>
      (username?.isNotEmpty ?? false) || (password?.isNotEmpty ?? false);

  /// The `Authorization` header value, or null when there are no
  /// credentials.
  String? get basicAuthHeader => hasCredentials
      ? 'Basic ${base64Encode(utf8.encode('${username ?? ''}:${password ?? ''}'))}'
      : null;

  @override
  bool operator ==(Object other) =>
      other is ServerConfig &&
      other.baseUrl == baseUrl &&
      other.username == username &&
      other.password == password &&
      other.access == access;

  @override
  int get hashCode => Object.hash(baseUrl, username, password, access);
}
