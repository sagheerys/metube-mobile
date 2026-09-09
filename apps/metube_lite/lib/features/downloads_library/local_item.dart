import 'package:mt_core/mt_core.dart';

/// Lite's media folder (§5.3). Its contents are registered in MediaStore so
/// they appear in the phone's gallery, and it is the same path as the old
/// Lite, so paths saved there remain valid.
const liteMediaDir = '/storage/emulated/0/Download/MeTube_Lite';

const _audioExtensions = {'mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'flac'};
const _videoExtensions = {'mp4', 'webm', 'mkv', 'mov', 'avi', '3gp', 'm4v'};

/// The media extensions shown in the local library.
bool isMediaFile(String path) {
  final ext = extensionOf(path);
  return _audioExtensions.contains(ext) || _videoExtensions.contains(ext);
}

/// A local library item: **the file on disk is the truth**, and the other
/// fields are enrichment from the indexes.
///
/// **The item key [key]:** the canonicalUrl when known (everything Lite v2
/// downloads knows its URL), otherwise **the absolute path**. That is what
/// makes the old Lite's data work as it is: its resume positions, playlists
/// and titles are all keyed by file paths (confirmed against a real backup:
/// 32 positions and 18 playlist entries).
class LocalItem {
  const LocalItem({
    required this.key,
    required this.path,
    required this.title,
    required this.sizeBytes,
    required this.modified,
    this.canonicalUrl,
    this.thumbnail,
    this.favorite = false,
    this.duration,
    this.aspectRatio,
  });

  final String key;
  final String path;
  final String title;
  final int sizeBytes;
  final DateTime modified;

  /// null means a file whose URL we do not know: migrated from the old
  /// Lite, or copied in by hand.
  final String? canonicalUrl;
  final String? thumbnail;
  final bool favorite;

  /// Clip dimensions from `media_shape_index`, known after the first play.
  final Duration? duration;
  final double? aspectRatio;

  String get filename => path.split(RegExp(r'[/\\]')).last;

  bool get isAudio => _audioExtensions.contains(extensionOf(path));

  MediaPlatform get platform => canonicalUrl == null
      ? MediaPlatform.other
      : MediaPlatform.detect(canonicalUrl!);

  /// A portrait video of three minutes or less is a "short". Unknown is not
  /// short: no guessing.
  bool get isShortForm =>
      !isAudio &&
      duration != null &&
      duration! <= const Duration(minutes: 3) &&
      aspectRatio != null &&
      aspectRatio! < 1;

  /// The default title when the title index has none: the filename without
  /// its extension and without the `_HHmmss` time stamp the name builder
  /// adds (§2.4).
  static String titleFromFilename(String filename) {
    final dot = filename.lastIndexOf('.');
    final stem = dot > 0 ? filename.substring(0, dot) : filename;
    return stem.replaceFirst(RegExp(r'_\d{6}$'), '');
  }
}

/// The scope filter in Lite: there is no "offline / server", because
/// everything is local.
enum LocalScope { all, favorites }

enum MediaTypeFilter { all, video, audio, shorts }

/// **The four view modes: one exclusive choice, not overlapping flags.**
///
/// They used to be two flags (`compact` and `grid`) that could be on
/// together meaninglessly, and the fourth mode, cards, would have made them
/// three flags with eight states, half of them impossible. One value
/// eliminates the impossible state at the root.
enum LibraryViewMode {
  /// A row with a thumbnail beside it. The default, and the best fit for
  /// long titles and for audio.
  list,

  /// Two columns with a 16:9 cover, for quick visual scanning.
  compact,

  /// Two columns with a 16:9 cover, for quick visual scanning.
  grid,

  /// **One column with a wide cover** (requested 2026-09-08, the YouTube
  /// pattern): the largest possible cover for the fewest items, for
  /// unhurried browsing rather than searching.
  cards,
}

/// The saved sort options (`video_sort_option`, §5.1).
enum LibrarySort { newest, oldest, nameAZ, nameZA, largest, smallest }

/// Building the view: pure, testable logic (TRD §3.2).
List<LocalItem> buildLocalLibraryView(
  List<LocalItem> items, {
  LocalScope scope = LocalScope.all,
  MediaTypeFilter type = MediaTypeFilter.all,
  String query = '',
  MediaPlatform? platform,
  LibrarySort sort = LibrarySort.newest,
}) {
  final q = query.trim().toLowerCase();
  final filtered = items.where((item) {
    if (scope == LocalScope.favorites && !item.favorite) return false;
    final typeOk = switch (type) {
      MediaTypeFilter.all => true,
      MediaTypeFilter.audio => item.isAudio,
      MediaTypeFilter.video => !item.isAudio,
      // Shorts: portrait, short, and only where the dimensions are known.
      MediaTypeFilter.shorts => item.isShortForm,
    };
    if (!typeOk) return false;
    if (platform != null && item.platform != platform) return false;
    if (q.isNotEmpty && !item.title.toLowerCase().contains(q)) return false;
    return true;
  }).toList();

  int byDate(LocalItem a, LocalItem b) => a.modified.compareTo(b.modified);
  int byName(LocalItem a, LocalItem b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
  int bySize(LocalItem a, LocalItem b) => a.sizeBytes.compareTo(b.sizeBytes);

  filtered.sort(switch (sort) {
    LibrarySort.newest => (a, b) => byDate(b, a),
    LibrarySort.oldest => byDate,
    LibrarySort.nameAZ => byName,
    LibrarySort.nameZA => (a, b) => byName(b, a),
    LibrarySort.largest => (a, b) => bySize(b, a),
    LibrarySort.smallest => bySize,
  });
  return filtered;
}

/// Live platform counters for the filter chips, most first. The unknown
/// platform (`other`) is placed last so it never leads the list.
List<MapEntry<MediaPlatform, int>> platformCounts(List<LocalItem> items) {
  final counts = <MediaPlatform, int>{};
  for (final item in items) {
    counts[item.platform] = (counts[item.platform] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      if ((a.key == MediaPlatform.other) != (b.key == MediaPlatform.other)) {
        return a.key == MediaPlatform.other ? 1 : -1;
      }
      return b.value.compareTo(a.value);
    });
  return entries;
}
