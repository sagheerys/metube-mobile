import 'url_keyed_index.dart';

/// The "available offline" index (Super): canonicalUrl to the local file
/// path. Prefs key: `offline_index` (§5.1, the old name kept for a smooth
/// migration).
final class OfflineIndex extends UrlKeyedIndex<String> {
  OfflineIndex({required super.store, required super.mutex})
      : super(prefsKey: 'offline_index');

  @override
  String? decodeValue(dynamic raw) {
    final s = raw?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  dynamic encodeValue(String value) => value;

  Future<String?> localPathOf(String canonicalUrl) => valueOf(canonicalUrl);

  Future<bool> isOffline(String canonicalUrl) async =>
      await valueOf(canonicalUrl) != null;
}
