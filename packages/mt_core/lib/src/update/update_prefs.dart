import '../storage/key_value_store.dart';

/// تفضيلات التحديث الذاتي (م-66) — مفاتيح `05-DATA-SCHEMA.md` §5.1.
///
/// **مخزن مستقل لا حقول في `SuperSettings`/`LiteSettings`**: الميزة
/// تدخل خلف مسار جديد فلا تمسّ تحميل الإعدادات ولا حفظها (ر-5).
class UpdatePrefs {
  UpdatePrefs({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const String autoCheckKey = 'update_auto_check';
  static const String lastCheckKey = 'update_last_check';
  static const String skippedVersionKey = 'update_skipped_version';

  /// **مفعّل افتراضياً**: من لا يفتح الإعدادات هو أحوج الناس للتحديث.
  Future<bool> autoCheck() async =>
      await store.getBool(autoCheckKey) ?? true;

  Future<void> setAutoCheck(bool value) =>
      mutex.run(() => store.setBool(autoCheckKey, value));

  Future<DateTime?> lastCheck() async {
    final ms = await store.getInt(lastCheckKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// يُختم **بعد كل محاولة** ناجحة كانت أو فاشلة: مستودع خاص أو شبكة
  /// مقطوعة يجب ألا يعيدا الطلب عند كل إقلاع.
  Future<void> markChecked(DateTime when) =>
      mutex.run(() => store.setInt(lastCheckKey, when.millisecondsSinceEpoch));

  Future<String?> skippedVersion() => store.getString(skippedVersionKey);

  Future<void> skipVersion(String version) =>
      mutex.run(() => store.setString(skippedVersionKey, version));

  /// يُنادى بعد تثبيت ناجح — وإلا ظلّ تخطٍّ قديم يكتم إصداراً لاحقاً
  /// لو تراجعت أرقام الإصدارات لأي سبب.
  Future<void> clearSkip() => mutex.run(() => store.remove(skippedVersionKey));
}
