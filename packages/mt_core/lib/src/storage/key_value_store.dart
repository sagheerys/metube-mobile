import 'package:synchronized/synchronized.dart';

/// واجهة التخزين المفتاحي — تُنفَّذ في التطبيق فوق SharedPreferences
/// (النواة Dart خالص فتُختبر بـ [MemoryKeyValueStore]).
/// أسماء المفاتيح من `05-DATA-SCHEMA.md` §5.1 حصراً.
abstract interface class KeyValueStore {
  /// القيمة الخام بأي نوع مخزن (String/bool/int/double/List of String).
  Future<Object?> get(String key);

  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
  Future<void> setInt(String key, int value);
  Future<void> setDouble(String key, double value);
  Future<void> setStringList(String key, List<String> value);
  Future<void> remove(String key);
  Future<Set<String>> keys();
}

/// قراءات مصنفة متسامحة فوق [KeyValueStore.get].
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

/// القفل الواحد لكل قراءة-تعديل-كتابة على التخزين (القاعدة 3) — تدفقان
/// متزامنان بلا قفل يقرآن نفس القيمة فيمحو البطيءُ كتابةَ الأسرع.
class PrefsMutex {
  final Lock _lock = Lock();

  /// تسلسل [body] مع كل استدعاءات هذا القفل في نفس الـ isolate.
  Future<T> run<T>(Future<T> Function() body) => _lock.synchronized(body);
}
