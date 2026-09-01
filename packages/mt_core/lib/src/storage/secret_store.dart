/// واجهة الأسرار — تُنفَّذ في التطبيق فوق flutter_secure_storage.
/// المفاتيح (`05-DATA-SCHEMA.md` §5.2): `username` · `password` ·
/// `backup_aes_key`. كلمة المرور **لا تدخل** أي نسخة احتياطية أو سجل.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// مفاتيح الأسرار المعتمدة — لا سلاسل حرة في مواقع النداء.
abstract final class SecretKeys {
  static const String username = 'username';
  static const String password = 'password';
  static const String backupAesKey = 'backup_aes_key';
}
