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
}
