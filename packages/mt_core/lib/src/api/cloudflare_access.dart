import 'package:dio/dio.dart';

import '../storage/secret_store.dart';

/// A Cloudflare Access service token: the pair of values the user creates in
/// the Zero Trust dashboard to let a client through Access without a browser
/// login.
///
/// **Held as a pair or not at all.** Access needs both headers; sending one
/// alone only produces a rejection that looks like a wrong address. So
/// [headersFor] answers nothing for a one-sided pair, and the settings screen
/// refuses to save one.
///
/// **No format check on purpose.** Cloudflare's token shape has changed
/// before and may again; a value Cloudflare does not like is reported by
/// Cloudflare as rejected credentials, which is the honest answer.
final class CloudflareAccess {
  /// The values are trimmed here, once, so every caller sees the same text
  /// (a pasted secret often carries a trailing line break).
  CloudflareAccess({required String clientId, required String clientSecret})
    : clientId = clientId.trim(),
      clientSecret = clientSecret.trim();

  static const String idHeader = 'CF-Access-Client-Id';
  static const String secretHeader = 'CF-Access-Client-Secret';

  final String clientId;
  final String clientSecret;

  bool get isComplete => clientId.isNotEmpty && clientSecret.isNotEmpty;

  /// What two settings fields hold: null when both are empty (no Access),
  /// otherwise the pair, which may be one-sided. A screen refuses to save a
  /// result whose [isComplete] is false.
  static CloudflareAccess? typed(String clientId, String clientSecret) {
    final access = CloudflareAccess(
      clientId: clientId,
      clientSecret: clientSecret,
    );
    return access.clientId.isEmpty && access.clientSecret.isEmpty
        ? null
        : access;
  }

  /// The stored pair, or null unless both halves are there: half a pair
  /// would only earn a rejection.
  static Future<CloudflareAccess?> load(SecretStore secrets) async {
    final access = CloudflareAccess(
      clientId: await secrets.read(SecretKeys.cfAccessClientId) ?? '',
      clientSecret: await secrets.read(SecretKeys.cfAccessClientSecret) ?? '',
    );
    return access.isComplete ? access : null;
  }

  /// Keeps [access] beside the server's password, or removes the stored
  /// pair when it is null or incomplete. Only a tested setting comes here.
  static Future<void> save(
    SecretStore secrets,
    CloudflareAccess? access,
  ) async {
    if (access == null || !access.isComplete) {
      await secrets.delete(SecretKeys.cfAccessClientId);
      await secrets.delete(SecretKeys.cfAccessClientSecret);
      return;
    }
    await secrets.write(SecretKeys.cfAccessClientId, access.clientId);
    await secrets.write(SecretKeys.cfAccessClientSecret, access.clientSecret);
  }

  /// The two headers for a request to [baseUrl], or nothing.
  ///
  /// **Only over https.** The secret is a live credential and Access is
  /// reached over HTTPS; a cleartext address (Super's local LAN address, for
  /// one, is not behind Cloudflare at all) must never receive it. An address
  /// typed without a scheme is not https either.
  Map<String, String> headersFor(String baseUrl) {
    if (!isComplete) return const {};
    if (!baseUrl.trimLeft().toLowerCase().startsWith('https://')) {
      return const {};
    }
    return {idHeader: clientId, secretHeader: clientSecret};
  }

  /// Whether [error] is the platform refusing to send one of our header
  /// values (measured): a `DioException` of type `unknown`
  /// whose cause is a `FormatException` that begins "Invalid HTTP header".
  ///
  /// **Only the start of the text is read, and the text is never kept**: the
  /// platform puts the secret itself in that message.
  static bool isRefusedHeaderValue(DioException error) =>
      error.type == DioExceptionType.unknown &&
      error.error is FormatException &&
      (error.error as FormatException).message.startsWith(
        'Invalid HTTP header',
      );

  @override
  bool operator ==(Object other) =>
      other is CloudflareAccess &&
      other.clientId == clientId &&
      other.clientSecret == clientSecret;

  @override
  int get hashCode => Object.hash(clientId, clientSecret);

  /// Redacted, so an innocent `'$access'` in a log line cannot leak it.
  @override
  String toString() => 'CloudflareAccess(***)';
}
