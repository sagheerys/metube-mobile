import 'dart:io';

import 'url_keyed_index.dart';

/// فهرس الأغلفة: canonicalUrl → رابط الغلاف الملتقط عند الإضافة —
/// البديل الوحيد المسموح لغير YouTube (لا اختلاق روابط ytimg، فخ §6.3).
/// مفتاح prefs: `artwork_index` (§5.1).
final class ArtworkIndex extends UrlKeyedIndex<String> {
  ArtworkIndex({required super.store, required super.mutex})
      : super(prefsKey: 'artwork_index');

  @override
  String? decodeValue(dynamic raw) {
    final s = raw?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  dynamic encodeValue(String value) => value;

  Future<String?> artworkOf(String canonicalUrl) => valueOf(canonicalUrl);

  /// **إزالة المدخلة وملفها على القرص معاً** (عطل المالك 2026-09-08).
  ///
  /// الحذف كان يزيل السطر من الفهرس ويترك ملف JPG يتيماً في
  /// `filesDir/thumbs` — وبعد نقل المصغرات من `cacheDir` (الذي يكنسه
  /// أندرويد) إلى `filesDir` (الذي لا يكنسه أحد) صار ذلك **تسريب
  /// مساحة بلا سقف**: ٣٠KB لكل حذف، لا يراها المستخدم ولا يستطيع
  /// استرجاعها إلا بمسح بيانات التطبيق كله.
  ///
  /// حارسان يمنعان حذف ما ليس لنا:
  /// * قيمة تبدأ بـ`http` رابط بعيد (أغلفة يوتيوب) لا ملف.
  /// * مسار ما زال مفتاحٌ آخر يشير إليه يبقى — لئلا يفقد عنصرٌ باقٍ
  ///   غلافه لأن جاره حُذف.
  Future<void> removeKeysAndFiles(Iterable<String> canonicalUrls) async {
    final doomed = canonicalUrls.toSet();
    if (doomed.isEmpty) return;
    final all = await readAll();
    final stillUsed = <String>{
      for (final entry in all.entries)
        if (!doomed.contains(entry.key)) entry.value,
    };
    for (final key in doomed) {
      final path = all[key];
      if (path == null || path.startsWith('http')) continue;
      if (stillUsed.contains(path)) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // ملف مقفل أو بلا صلاحية — المدخلة تُزال على أي حال.
      }
    }
    await mutate((map) => map.removeWhere((k, _) => doomed.contains(k)));
  }
}
