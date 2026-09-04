import 'dart:convert';

import 'key_value_store.dart';

/// أساس مشترك للفهارس المخزنة كخريطة JSON تحت مفتاح واحد —
/// **المفتاح الموحد دائماً canonicalUrl** (`05-DATA-SCHEMA.md` §5.5)،
/// وكل تعديل قراءة-تعديل-كتابة داخل [PrefsMutex].
abstract base class UrlKeyedIndex<V> {
  UrlKeyedIndex({
    required this.store,
    required this.mutex,
    required this.prefsKey,
    this.onChanged,
  });

  final KeyValueStore store;
  final PrefsMutex mutex;
  final String prefsKey;

  /// **يُنادى بعد كل كتابة ناجحة** — نقطة الاختناق الوحيدة للفهرس.
  /// يستعملها التطبيق ليطلب نسخة تلقائية بدل نثر النداء في كل شاشة
  /// تكتب (وكان نثره يعني نسيان واحدة حتماً).
  final void Function()? onChanged;

  /// تحويل قيمة JSON الخام إلى [V] — تجاوز غير الصالح بإرجاع null.
  V? decodeValue(dynamic raw);
  dynamic encodeValue(V value);

  Future<Map<String, V>> readAll() async {
    final raw = await store.getString(prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      final result = <String, V>{};
      for (final entry in decoded.entries) {
        final value = decodeValue(entry.value);
        if (value != null) result[entry.key.toString()] = value;
      }
      return result;
    } on FormatException {
      return {};
    }
  }

  Future<V?> valueOf(String canonicalUrl) async =>
      (await readAll())[canonicalUrl];

  Future<void> put(String canonicalUrl, V value) =>
      mutate((map) => map[canonicalUrl] = value);

  Future<void> removeKey(String canonicalUrl) =>
      mutate((map) => map.remove(canonicalUrl));

  /// قراءة-تعديل-كتابة ذرّية تحت القفل.
  Future<void> mutate(void Function(Map<String, V> map) apply) =>
      mutex.run(() async {
        final map = await readAll();
        apply(map);
        await store.setString(
          prefsKey,
          json.encode(map.map((k, v) => MapEntry(k, encodeValue(v)))),
        );
        onChanged?.call();
      });

  Future<void> clear() => mutex.run(() async {
        await store.remove(prefsKey);
        onChanged?.call();
      });
}
