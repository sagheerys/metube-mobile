import 'key_value_store.dart';
import 'secret_store.dart';

/// تنفيذ ذاكرة لـ [KeyValueStore] — للاختبارات وسكربت بوابة 2 الخالص.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object> _data = {};

  /// لقطة للقراءة في الاختبارات.
  Map<String, Object> get snapshot => Map.unmodifiable(_data);

  @override
  Future<Object?> get(String key) async => _data[key];

  @override
  Future<void> setString(String key, String value) async => _data[key] = value;

  @override
  Future<void> setBool(String key, bool value) async => _data[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _data[key] = value;

  @override
  Future<void> setDouble(String key, double value) async => _data[key] = value;

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _data[key] = List<String>.from(value);

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Future<Set<String>> keys() async => _data.keys.toSet();
}

/// تنفيذ ذاكرة لـ [SecretStore] — للاختبارات فقط (لا تشفير).
class MemorySecretStore implements SecretStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}
