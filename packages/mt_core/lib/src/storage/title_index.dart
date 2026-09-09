import 'url_keyed_index.dart';

/// The title index: item key to the displayed title.
///
/// The prefs key `video_title_metadata` is **kept from the old Lite
/// deliberately** (§5.1: keeping legacy key names where possible makes
/// importing backups easier). In a real backup it holds 48 titles keyed by
/// **file path** rather than URL, so in Lite it is read by item key, the
/// canonicalUrl when known and the absolute path otherwise, rather than by
/// URL alone.
final class TitleIndex extends UrlKeyedIndex<String> {
  TitleIndex({required super.store, required super.mutex})
    : super(prefsKey: 'video_title_metadata');

  @override
  String? decodeValue(dynamic raw) {
    // The old Lite stores the title as a string; older versions stored a
    // `{title: …}` map.
    final value = raw is Map ? raw['title'] : raw;
    final s = value?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  dynamic encodeValue(String value) => value;

  Future<String?> titleOf(String itemKey) => valueOf(itemKey);
}
