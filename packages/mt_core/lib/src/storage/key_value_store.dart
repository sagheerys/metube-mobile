import 'package:synchronized/synchronized.dart';

/// The key-value storage interface, implemented in the app over
/// SharedPreferences. The core is pure Dart, so it is tested with
/// [MemoryKeyValueStore]. Key names come from `05-DATA-SCHEMA.md` §5.1 and
/// nowhere else.
abstract interface class KeyValueStore {
  /// The raw value in whatever type was stored (String, bool, int, double,
  /// List of String).
  Future<Object?> get(String key);

  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> setInt(String key, int value);
  Future<void> setDouble(String key, double value);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
  Future<Set<String>> keys();
}

/// Tolerant typed reads over [KeyValueStore.get].
extension TypedReads on KeyValueStore {
  Future<String?> getString(String key) async {
    final v = await get(key);
    return v is String ? v : null;
  }

  Future<bool?> getBool(String key) async {
    final v = await get(key);
    return v is bool ? v : null;
  }

  Future<int?> getInt(String key) async {
    final v = await get(key);
    return v is int ? v : null;
  }

  Future<double?> getDouble(String key) async {
    final v = await get(key);
    return v is num ? v.toDouble() : null;
  }

  Future<List<String>?> getStringList(String key) async {
    final v = await get(key);
    return v is List ? v.map((e) => e.toString()).toList() : null;
  }
}

/// The one lock for every read-modify-write against storage (rule 3): two
/// concurrent flows without it read the same value, and the slower one
/// erases the faster one's write.
class PrefsMutex {
  final Lock _lock = Lock();

  /// Serialises [body] against every other call to this lock in the same
  /// isolate.
  Future<T> run<T>(Future<T> Function() body) => _lock.synchronized(body);
}
