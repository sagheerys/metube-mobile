import 'url_keyed_index.dart';

/// The tags index (Super): canonicalUrl to the user's list of tags. Prefs
/// key: `tags_index` (§5.1). Deleting a tag never deletes media.
final class TagsIndex extends UrlKeyedIndex<List<String>> {
  TagsIndex({required super.store, required super.mutex, super.onChanged})
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

  /// Adds or removes a tag for one item, from a chip tap in the tags sheet.
  Future<void> toggleTag(String canonicalUrl, String tag) => mutate((map) {
    final tags = List<String>.from(map[canonicalUrl] ?? const []);
    tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
    tags.isEmpty ? map.remove(canonicalUrl) : map[canonicalUrl] = tags;
  });

  /// Every tag with how many items carry it, for the "your tags" chips.
  Future<Map<String, int>> allTagsWithCounts() async {
    final counts = <String, int>{};
    for (final tags in (await readAll()).values) {
      for (final tag in tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// The items carrying one tag, for filtering the library.
  Future<List<String>> urlsWithTag(String tag) async => [
    for (final entry in (await readAll()).entries)
      if (entry.value.contains(tag)) entry.key,
  ];

  /// Renames a tag across every item, **without duplicating:** an
  /// item carrying both the old and the new name ended up carrying the new
  /// one twice, which inflated the chip counter and showed the item twice
  /// in
  /// the filter.
  Future<void> renameTag(String oldName, String newName) => mutate((map) {
    for (final entry in map.entries) {
      final idx = entry.value.indexOf(oldName);
      if (idx < 0) continue;
      if (entry.value.contains(newName)) {
        entry.value.removeAt(idx);
      } else {
        entry.value[idx] = newName;
      }
    }
  });

  /// Deletes a tag from every item. The media stays.
  Future<void> deleteTag(String tag) => mutate((map) {
    final emptied = <String>[];
    for (final entry in map.entries) {
      entry.value.remove(tag);
      if (entry.value.isEmpty) emptied.add(entry.key);
    }
    emptied.forEach(map.remove);
  });
}
