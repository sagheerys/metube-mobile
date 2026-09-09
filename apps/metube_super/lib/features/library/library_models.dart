import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart' show MTMediaLocation;

const _audioExtensions = {'mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'flac'};

/// The unified library item: the server history merged with the local
/// index on the canonicalUrl key, with a location badge on each one.
class LibraryItem {
  const LibraryItem({
    required this.canonicalUrl,
    required this.title,
    this.uploader,
    this.thumbnail,
    this.serverFilename,
    this.localPath,
    this.timestamp,
    this.sizeBytes,
    this.onServer = false,
    this.isAudio = false,
    this.favorite = false,
    this.tags = const [],
    this.duration,
    this.aspectRatio,
  });

  final String canonicalUrl;
  final String title;
  final String? uploader;
  final String? thumbnail;
  final String? serverFilename;
  final String? localPath;
  final DateTime? timestamp;
  final int? sizeBytes;
  final bool onServer;
  final bool isAudio;
  final bool favorite;
  final List<String> tags;

  /// Clip dimensions from `media_shape_index`, known after the first play.
  final Duration? duration;
  final double? aspectRatio;

  bool get isOffline => localPath != null;

  /// The platform from the canonical URL: one approved detector, never a
  /// second list.
  MediaPlatform get platform => MediaPlatform.detect(canonicalUrl);

  /// A portrait video of three minutes or less is a "short". Unknown is not
  /// short: no guessing.
  bool get isShortForm =>
      !isAudio &&
      duration != null &&
      duration! <= const Duration(minutes: 3) &&
      aspectRatio != null &&
      aspectRatio! < 1;

  MTMediaLocation get location => switch ((isOffline, onServer)) {
    (true, true) => MTMediaLocation.both,
    (true, false) => MTMediaLocation.offline,
    (false, true) => MTMediaLocation.onServer,
    _ => MTMediaLocation.none,
  };

  /// [cachedThumb] is the cover from the artwork index, **in practice the
  /// only source on a real server**: `/history` returns no `thumbnail` for
  /// any item (zero out of 252), and the cover is generated locally by
  /// `MediaProbe` (field report).
  factory LibraryItem.fromHistory(
    HistoryItem item, {
    String? localPath,
    bool favorite = false,
    List<String> tags = const [],
    Duration? duration,
    double? aspectRatio,
    String? cachedThumb,
  }) => LibraryItem(
    duration: duration,
    aspectRatio: aspectRatio,
    canonicalUrl: item.canonicalUrl,
    title: item.title ?? item.filename ?? item.canonicalUrl,
    uploader: item.uploader,
    thumbnail: item.thumbnail ?? cachedThumb,
    serverFilename: item.filename,
    localPath: localPath,
    timestamp: item.timestamp,
    sizeBytes: item.sizeBytes,
    onServer: true,
    isAudio: _looksAudio(item.quality, item.format, item.filename),
    favorite: favorite,
    tags: tags,
  );

  /// A local item no longer on the server; its metadata comes from its
  /// path.
  factory LibraryItem.fromOfflineOnly(
    String canonicalUrl,
    String localPath, {
    bool favorite = false,
    List<String> tags = const [],
    String? cachedThumb,
    Duration? duration,
    double? aspectRatio,
  }) {
    final basename = localPath.split(RegExp(r'[/\\]')).last;
    final dot = basename.lastIndexOf('.');
    return LibraryItem(
      duration: duration,
      aspectRatio: aspectRatio,
      canonicalUrl: canonicalUrl,
      title: dot > 0 ? basename.substring(0, dot) : basename,
      localPath: localPath,
      thumbnail: cachedThumb,
      isAudio: _looksAudio(null, null, basename),
      favorite: favorite,
      tags: tags,
    );
  }

  static bool _looksAudio(String? quality, String? format, String? filename) {
    if (quality == 'audio') return true;
    if (format != null && _audioExtensions.contains(format.toLowerCase())) {
      return true;
    }
    final ext = extensionOf(filename);
    return _audioExtensions.contains(ext);
  }
}

/// Library filters: all, favourites, offline, server.
enum LibraryScope { all, favorites, offline, onServer }

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

/// The saved sort options (video_sort_option, §5.1).
enum LibrarySort { newest, oldest, nameAZ, nameZA, largest, smallest }

/// Building the view: pure, testable logic (TRD §3.2).
List<LibraryItem> buildLibraryView(
  List<LibraryItem> items, {
  LibraryScope scope = LibraryScope.all,
  MediaTypeFilter type = MediaTypeFilter.all,
  String query = '',
  Set<String> tags = const {},
  Set<String> excludedTags = const {},
  MediaPlatform? platform,
  LibrarySort sort = LibrarySort.newest,
}) {
  final q = query.trim().toLowerCase();
  final filtered = items.where((item) {
    final scopeOk = switch (scope) {
      LibraryScope.all => true,
      LibraryScope.favorites => item.favorite,
      LibraryScope.offline => item.isOffline,
      LibraryScope.onServer => item.onServer,
    };
    if (!scopeOk) return false;
    final typeOk = switch (type) {
      MediaTypeFilter.all => true,
      MediaTypeFilter.audio => item.isAudio,
      MediaTypeFilter.video => !item.isAudio,
      // Shorts: portrait, short, and only where the dimensions are known.
      MediaTypeFilter.shorts => item.isShortForm,
    };
    if (!typeOk) return false;
    if (platform != null && item.platform != platform) return false;
    // **Compound tag filtering**: included tags are combined with OR
    // (widening: show me tech or science), while excluded ones are always
    // subtracted and beat inclusion. An exclusion is an explicit intention
    // that another tag on the same item must not be able to override.
    if (tags.isNotEmpty && !item.tags.any(tags.contains)) return false;
    if (item.tags.any(excludedTags.contains)) return false;
    if (q.isNotEmpty && !item.title.toLowerCase().contains(q)) return false;
    return true;
  }).toList();

  int byDate(LibraryItem a, LibraryItem b) =>
      (a.timestamp ?? DateTime(0)).compareTo(b.timestamp ?? DateTime(0));
  int byName(LibraryItem a, LibraryItem b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
  int bySize(LibraryItem a, LibraryItem b) =>
      (a.sizeBytes ?? 0).compareTo(b.sizeBytes ?? 0);

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

/// Live platform counters, most first, with unknown last.
///
/// **The counterpart of `apps/metube_lite/.../local_item.dart`**: the same
/// order and the same "unknown never leads" rule. Any change here is
/// considered for its twin.
List<MapEntry<MediaPlatform, int>> platformCounts(List<LibraryItem> items) {
  final counts = <MediaPlatform, int>{};
  for (final item in items) {
    counts[item.platform] = (counts[item.platform] ?? 0) + 1;
  }
  return counts.entries.toList()..sort((a, b) {
    if ((a.key == MediaPlatform.other) != (b.key == MediaPlatform.other)) {
      return a.key == MediaPlatform.other ? 1 : -1;
    }
    return b.value.compareTo(a.value);
  });
}
