import '../models/playlist_item.dart';

/// **The filtered shorts lane**: pure, testable logic.
///
/// A strict rule: swiping moves between the portrait shorts of the list on
/// screen **in that same order**; audio and landscape items are skipped
/// silently, and the counter counts shorts alone. Unknown, with no
/// duration or ratio, is not short. No guessing.
class ShortsLane {
  const ShortsLane._(this.items, this.sourceIndices);

  /// The shorts only, in the original list's order.
  final List<PlaylistItem> items;

  /// Each item's index inside the original list, for returning to the rest
  /// of it.
  final List<int> sourceIndices;

  bool get isEmpty => items.isEmpty;
  int get length => items.length;

  /// Builds the lane from the list on screen.
  factory ShortsLane.from(List<PlaylistItem> source) {
    final items = <PlaylistItem>[];
    final indices = <int>[];
    for (var i = 0; i < source.length; i++) {
      if (source[i].isShortForm) {
        items.add(source[i]);
        indices.add(i);
      }
    }
    return ShortsLane._(items, indices);
  }

  /// An item's position inside the lane, or -1 when it is not a short.
  int laneIndexOf(String canonicalUrl) =>
      items.indexWhere((i) => i.canonicalUrl == canonicalUrl);

  /// The first **non-short** item after the lane ends; the "continue with
  /// the rest of the list" button opens it in its correct player. null when
  /// nothing is left.
  int? nextNonShortIndex(List<PlaylistItem> source) {
    final last = sourceIndices.isEmpty ? -1 : sourceIndices.last;
    for (var i = last + 1; i < source.length; i++) {
      if (!source[i].isShortForm) return i;
    }
    for (var i = 0; i < source.length; i++) {
      if (!source[i].isShortForm) return i;
    }
    return null;
  }
}
