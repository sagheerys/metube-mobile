/// The secrets interface, implemented in the app over
/// flutter_secure_storage. The keys (`05-DATA-SCHEMA.md` §5.2) are
/// `username`, `password` and `backup_aes_key`. The password **never
/// enters** a backup or a log.
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
}
