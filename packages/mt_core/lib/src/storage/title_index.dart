import 'url_keyed_index.dart';

/// فهرس العناوين: مفتاح العنصر → العنوان المعروض.
///
/// مفتاح prefs `video_title_metadata` **مُبقى من Lite القديم عمداً**
/// (§5.1: «إبقاء أسماء المفاتيح القديمة حيث أمكن يسهّل استيراد النسخ
/// الاحتياطية»). في نسخة المالك الحقيقية يحمل 48 عنواناً مفتاحها
/// **مسار الملف** لا الرابط — لذلك يُقرأ بمفتاح العنصر في Lite
/// (canonicalUrl إن عُرف وإلا المسار المطلق) لا بالرابط حصراً.
final class TitleIndex extends UrlKeyedIndex<String> {
  TitleIndex({required super.store, required super.mutex})
      : super(prefsKey: 'video_title_metadata');

  @override
  String? decodeValue(dynamic raw) {
    // Lite القديم يخزّن العنوان نصاً؛ نسخ أقدم خزّنت خريطة `{title: …}`.
    final value = raw is Map ? raw['title'] : raw;
    final s = value?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  dynamic encodeValue(String value) => value;

  Future<String?> titleOf(String itemKey) => valueOf(itemKey);
}
