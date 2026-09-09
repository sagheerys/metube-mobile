import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// An item inside a saved playlist, keyed by canonicalUrl (§5.1: entries
/// in `saved_playlists` are `{canonicalUrl, serverFilename, cachedTitle,
/// cachedThumb}`). [legacyPath] carries the old Lite format's file path
/// until the app resolves it to a canonicalUrl during migration.
class PlaylistEntry {
  const PlaylistEntry({
    required this.canonicalUrl,
    this.serverFilename,
    this.cachedTitle,
    this.cachedThumb,
    this.legacyPath,
  });

  final String canonicalUrl;
  final String? serverFilename;
  final String? cachedTitle;
  final String? cachedThumb;
  final String? legacyPath;

  bool get isLegacy => canonicalUrl.isEmpty && legacyPath != null;

  Map<String, dynamic> toJson() => {
        'canonicalUrl': canonicalUrl,
        if (serverFilename != null) 'serverFilename': serverFilename,
        if (cachedTitle != null) 'cachedTitle': cachedTitle,
        if (cachedThumb != null) 'cachedThumb': cachedThumb,
        if (legacyPath != null) 'legacyPath': legacyPath,
      };

  factory PlaylistEntry.fromJson(Map<String, dynamic> json) => PlaylistEntry(
        canonicalUrl: json['canonicalUrl']?.toString() ?? '',
        serverFilename: json['serverFilename']?.toString(),
        cachedTitle: json['cachedTitle']?.toString(),
        cachedThumb: json['cachedThumb']?.toString(),
        legacyPath: json['legacyPath']?.toString(),
      );
}

/// A saved playlist, with pinning and last-played time.
class SavedPlaylist {
  SavedPlaylist({
    String? id,
    required this.name,
    List<PlaylistEntry>? items,
    this.pinned = false,
    DateTime? createdAt,
    this.lastPlayedAt,
  })  : id = id ?? _uuid.v4(),
        items = items ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  final List<PlaylistEntry> items;
  bool pinned;
  final DateTime createdAt;
  DateTime? lastPlayedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'pinned': pinned,
        if (lastPlayedAt != null)
          'lastPlayedAt': lastPlayedAt!.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory SavedPlaylist.fromJson(Map<String, dynamic> json) {
    // The old Lite format: {name, createdAt, videoPaths: [file paths]}.
    if (json.containsKey('videoPaths')) {
      return SavedPlaylist.fromLegacyLite(json);
    }
    // **A migration confirmed against a real backup (2026-09-01):** the old
    // Super names the item array `entries` with the same fields. Without
    // this
    // alternative, playlists imported silently empty.
    final rawItems = json['items'] as List? ?? json['entries'] as List?;
    return SavedPlaylist(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      pinned: json['pinned'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      lastPlayedAt: DateTime.tryParse(json['lastPlayedAt']?.toString() ?? ''),
      items: [
        for (final item in rawItems ?? const [])
          if (item is Map)
            PlaylistEntry.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  /// Migrates the old path-based Lite format: every path becomes a
  /// [PlaylistEntry.isLegacy] until the app ties it to a canonical URL.
  factory SavedPlaylist.fromLegacyLite(Map<String, dynamic> json) =>
      SavedPlaylist(
        name: json['name']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        items: [
          for (final path in (json['videoPaths'] as List? ?? const []))
            PlaylistEntry(canonicalUrl: '', legacyPath: path.toString()),
        ],
      );
}
