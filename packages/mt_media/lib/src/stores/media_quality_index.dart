import 'package:mt_core/mt_core.dart';

import '../models/media_quality.dart';

/// Each clip's [MediaQuality] as read from its header: canonicalUrl to the
/// answer.
///
/// Reading a header from the server takes a round trip long enough to
/// notice, and a file's resolution never changes once it has downloaded.
/// So the answer is kept across launches, and the details sheet shows it at
/// once instead of saying "reading" every time. An item re-downloaded under
/// the same URL at another quality is not a stale risk: deleting it prunes
/// this entry along with its other data.
///
/// Only answers are stored. A failed read stays unknown so the next opening
/// tries again. Storage key: `media_quality_index`.
final class MediaQualityIndex extends UrlKeyedIndex<MediaQuality> {
  MediaQualityIndex({required super.store, required super.mutex})
    : super(prefsKey: 'media_quality_index');

  @override
  MediaQuality? decodeValue(dynamic raw) {
    if (raw is! Map) return null;
    final quality = MediaQuality.fromMap(raw);
    return quality.isEmpty ? null : quality;
  }

  @override
  dynamic encodeValue(MediaQuality value) => value.toMap();

  /// Stores [quality] unless it says nothing.
  Future<void> remember(String canonicalUrl, MediaQuality quality) async {
    if (canonicalUrl.isEmpty || quality.isEmpty) return;
    await put(canonicalUrl, quality);
  }
}
