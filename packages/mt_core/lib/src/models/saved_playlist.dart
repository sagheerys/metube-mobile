import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// عنصر داخل قائمة محفوظة — بمفتاح canonicalUrl (§5.1: عناصر
/// `saved_playlists` هي `{canonicalUrl, serverFilename, cachedTitle,
/// cachedThumb}`). [legacyPath] يحمل مسار صيغة Lite القديمة حتى يحلّه
/// التطبيق إلى canonicalUrl عند الهجرة.
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

/// قائمة تشغيل محفوظة (م-25) مع التثبيت وآخر تشغيل (م-37/ب).
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
    // صيغة Lite القديمة: {name, createdAt, videoPaths: [مسارات ملفات]}.
    if (json.containsKey('videoPaths')) {
      return SavedPlaylist.fromLegacyLite(json);
    }
    // **هجرة مُثبتة على نسخة المالك الحقيقية (2026-09-01):** Super
    // القديم يسمي مصفوفة العناصر `entries` بنفس حقولها — بلا هذا
    // البديل تُستورد القوائم فارغة بصمت.
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

  /// هجرة صيغة Lite القديمة القائمة على مسارات الملفات — كل مسار يصبح
  /// [PlaylistEntry.isLegacy] حتى يربطه التطبيق بالرابط المُقنون.
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
