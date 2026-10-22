import 'package:mt_core/mt_core.dart' show MediaPlatform;

import 'library_models.dart';

/// View options plus multi-select. Sorting and the view mode are saved.
class LibraryViewOptions {
  const LibraryViewOptions({
    this.scope = LibraryScope.all,
    this.type = MediaTypeFilter.all,
    this.query = '',
    this.tags = const {},
    this.excludedTags = const {},
    this.platform,
    this.channel,
    this.folder,
    this.sort = LibrarySort.newest,
    this.mode = LibraryViewMode.list,
    this.selection = const {},
  });

  final LibraryScope scope;
  final MediaTypeFilter type;
  final String query;

  /// Included tags (OR between them) and excluded ones: compound filtering
  /// with no extra screen.
  final Set<String> tags;
  final Set<String> excludedTags;

  /// **The platform filter** (requested 2026-09-08, as in Lite): it lives
  /// in the sort sheet rather than a third row of chips, because this
  /// library already has a filter row and a tag row above it and a third
  /// would push the first card off screen. The chosen platform appears as a
  /// removable chip in **the first row**.
  final MediaPlatform? platform;

  /// **One channel's clips only**. Set by tapping the channel name
  /// on a card, cleared from its chip in the first row — the same shape as
  /// [platform], and deliberately **not** a tag: a tag is something the
  /// user creates, and this is something the server already knows.
  final String? channel;

  /// **One top server folder's clips only** (see [LibraryItem.topFolder]),
  /// chosen in the sort sheet like [platform] and shown as a removable chip
  /// in the first row.
  final String? folder;
  final LibrarySort sort;

  /// The saved view mode: one of four, not overlapping flags.
  final LibraryViewMode mode;

  bool get compact => mode == LibraryViewMode.compact;
  bool get grid => mode == LibraryViewMode.grid;
  bool get cards => mode == LibraryViewMode.cards;

  /// The selected canonical URLs; a non-empty set means selection mode.
  final Set<String> selection;

  bool get selecting => selection.isNotEmpty;

  /// How many filters are active above "all", for the sort button's badge.
  int get activeFilters =>
      (scope == LibraryScope.all ? 0 : 1) +
      (type == MediaTypeFilter.all ? 0 : 1) +
      (platform == null ? 0 : 1) +
      (channel == null ? 0 : 1) +
      (folder == null ? 0 : 1) +
      tags.length +
      excludedTags.length;

  LibraryViewOptions copyWith({
    LibraryScope? scope,
    MediaTypeFilter? type,
    String? query,
    Set<String>? tags,
    Set<String>? excludedTags,
    MediaPlatform? Function()? platform,
    String? Function()? channel,
    String? Function()? folder,
    LibrarySort? sort,
    LibraryViewMode? mode,
    Set<String>? selection,
  }) => LibraryViewOptions(
    scope: scope ?? this.scope,
    type: type ?? this.type,
    query: query ?? this.query,
    tags: tags ?? this.tags,
    excludedTags: excludedTags ?? this.excludedTags,
    // A function rather than a value: `null` means "no change" for
    // every other field, and here `null` is a valid value meaning "all
    // platforms".
    platform: platform == null ? this.platform : platform(),
    // Same reason as platform: null is a real value here, "every channel".
    channel: channel == null ? this.channel : channel(),
    folder: folder == null ? this.folder : folder(),
    sort: sort ?? this.sort,
    mode: mode ?? this.mode,
    selection: selection ?? this.selection,
  );
}
