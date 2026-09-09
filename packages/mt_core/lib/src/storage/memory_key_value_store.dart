import 'key_value_store.dart';
import 'secret_store.dart';

/// An in-memory [KeyValueStore], for tests and for the pure gate-2 script.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object> _data = {};

  /// A read-only snapshot for tests.
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

/// An in-memory [SecretStore] for tests only, with no encryption.
class MemorySecretStore implements SecretStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}
