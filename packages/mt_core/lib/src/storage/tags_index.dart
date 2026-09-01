import 'url_keyed_index.dart';

/// فهرس الوسوم (Super — م-26): canonicalUrl → قائمة وسوم المستخدم.
/// مفتاح prefs: `tags_index` (§5.1). حذف وسم لا يحذف الوسائط أبداً.
final class TagsIndex extends UrlKeyedIndex<List<String>> {
  TagsIndex({required super.store, required super.mutex})
      : super(prefsKey: 'tags_index');

  @override
  List<String>? decodeValue(dynamic raw) {
    if (raw is! List) return null;
    final tags = raw
        .map((e) => e.toString().trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return tags.isEmpty ? null : tags;
  }

  @override
  dynamic encodeValue(List<String> value) => value;

  Future<List<String>> tagsOf(String canonicalUrl) async =>
      await valueOf(canonicalUrl) ?? const [];

  /// إضافة/إزالة وسم لعنصر (نقرة الرقاقة في ورقة الوسوم).
  Future<void> toggleTag(String canonicalUrl, String tag) =>
      mutate((map) {
        final tags = List<String>.from(map[canonicalUrl] ?? const []);
        tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
        tags.isEmpty ? map.remove(canonicalUrl) : map[canonicalUrl] = tags;
      });

  /// كل الوسوم بعدد عناصر كل منها (رقاقات «وسومك» م-37/ج).
  Future<Map<String, int>> allTagsWithCounts() async {
    final counts = <String, int>{};
    for (final tags in (await readAll()).values) {
      for (final tag in tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// عناصر وسم معين (تصفية المكتبة).
  Future<List<String>> urlsWithTag(String tag) async => [
        for (final entry in (await readAll()).entries)
          if (entry.value.contains(tag)) entry.key,
      ];

  /// إعادة تسمية وسم عبر كل العناصر.
  Future<void> renameTag(String oldName, String newName) => mutate((map) {
        for (final entry in map.entries) {
          final idx = entry.value.indexOf(oldName);
          if (idx >= 0) {
            entry.value[idx] = newName;
          }
        }
      });

  /// حذف وسم من كل العناصر — الوسائط تبقى.
  Future<void> deleteTag(String tag) => mutate((map) {
        final emptied = <String>[];
        for (final entry in map.entries) {
          entry.value.remove(tag);
          if (entry.value.isEmpty) emptied.add(entry.key);
        }
        emptied.forEach(map.remove);
      });
}
