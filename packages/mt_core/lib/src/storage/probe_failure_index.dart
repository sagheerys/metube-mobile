import 'url_keyed_index.dart';

/// **A memory of probe failures** (the thumbnail defect, 2026-09-07):
/// canonicalUrl to the moment of the last failure.
///
/// Without it, an impossible item is re-probed **at every launch**: one
/// library record for a file deleted from the server's disk consumed over
/// 80 seconds every session, because the Android platform retries ten
/// times on an 8s timeout, and it froze the queue behind it. So the
/// library stayed without thumbnails except for YouTube, whose covers are
/// derived rather than probed.
final class ProbeFailureIndex extends UrlKeyedIndex<DateTime> {
  ProbeFailureIndex({required super.store, required super.mutex})
    : super(prefsKey: 'probe_failures');

  /// How long before we forget: the file may come back, re-uploaded or the
  /// server restored.
  static const retryAfter = Duration(days: 1);

  @override
  DateTime? decodeValue(dynamic raw) {
    final ms = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  dynamic encodeValue(DateTime value) => value.millisecondsSinceEpoch;

  /// Should this item be skipped right now, because it failed recently?
  bool isCoolingDown(
    Map<String, DateTime> failures,
    String canonicalUrl, {
    DateTime? now,
  }) {
    final at = failures[canonicalUrl];
    if (at == null) return false;
    return (now ?? DateTime.now()).difference(at) < retryAfter;
  }
}
