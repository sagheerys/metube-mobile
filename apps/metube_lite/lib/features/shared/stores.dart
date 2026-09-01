import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mt_core/mt_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تنفيذ [KeyValueStore] فوق SharedPreferences — الوصول الوحيد للتخزين
/// (القاعدة 3: كل قراءة-تعديل-كتابة عبر PrefsMutex في مواقع النداء).
class SharedPrefsKeyValueStore implements KeyValueStore {
  SharedPrefsKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<Object?> get(String key) async => _prefs.get(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);

  @override
  Future<Set<String>> keys() async => _prefs.getKeys();
}

/// تنفيذ [SecretStore] فوق flutter_secure_storage (Android Keystore).
class SecureSecretStore implements SecretStore {
  const SecureSecretStore();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
