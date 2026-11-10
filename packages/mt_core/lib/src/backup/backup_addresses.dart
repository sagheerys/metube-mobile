import '../storage/key_value_store.dart';

/// The server addresses inside a backup: kept clean of credentials on the
/// way out and on the way in, and compared before and after a restore.
abstract final class BackupAddresses {
  /// **Keys that say where the server is**, in all three apps. The
  /// password and the Cloudflare token live in the secret store, which a
  /// restore does not touch, and go to whatever address these keys hold.
  /// A file that names an address this install did not know would have
  /// them sent there: a "backup" handed over by someone else is enough.
  static const keys = {
    'server_url',
    'active_url',
    'local_url',
    'external_urls',
    'ember_server_url',
    'ember_server_addresses',
    'ember_server_active',
  };

  /// The servers named under [keys] in [store], as `scheme://host:port`.
  static Future<Set<String>> knownServers(KeyValueStore store) async {
    final servers = <String>{};
    void add(Object? value) {
      if (value is List) {
        value.forEach(add);
        return;
      }
      if (value is! String) return;
      final uri = Uri.tryParse(value.trim());
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) return;
      servers.add(
        '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}:${uri.port}',
      );
    }

    for (final key in keys) {
      add(await store.get(key));
    }
    return servers;
  }

  /// **Strip credentials embedded in a URL.** Excluding the password from
  /// the backup is correct, but someone who pastes `https://user:pass@host`
  /// as the server URL puts it in an ordinary string key, so it entered the
  /// backup despite the rule. **Any key whose value is a web address**, not
  /// a list of known ones: the Windows app keeps its addresses under keys
  /// of its own, and a list of names missed them.
  static Object? sanitize(Object? value) {
    if (value is String) return stripIfUrl(value);
    if (value is List) {
      return [for (final v in value) v is String ? stripIfUrl(v) : v];
    }
    return value;
  }

  /// [value] without credentials when it is a web address, else unchanged.
  static String stripIfUrl(String value) {
    final lower = value.trimLeft().toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://')
        ? stripCredentials(value)
        : value;
  }

  /// Returns the URL without `user:pass@`, and anything that is not a URL
  /// unchanged.
  static String stripCredentials(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.userInfo.isEmpty) return raw;
    return uri.replace(userInfo: '').toString();
  }
}
