/// The secrets interface, implemented in the app over
/// flutter_secure_storage. The keys are
/// `username`, `password`, `backup_aes_key`, `cf_access_client_id` and
/// `cf_access_client_secret`. None of them **ever enters** a backup or a log.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The approved secret keys, so no free-form strings appear at call sites.
abstract final class SecretKeys {
  static const String username = 'username';
  static const String password = 'password';
  static const String backupAesKey = 'backup_aes_key';

  /// The Cloudflare Access service token. Written only by
  /// Settings → Server and never restored from a backup.
  static const String cfAccessClientId = 'cf_access_client_id';
  static const String cfAccessClientSecret = 'cf_access_client_secret';
}
