import 'package:uuid/uuid.dart';

import '../urls/url_kit.dart';

const _uuid = Uuid();

/// The state of a `/history` item after the server's synonyms are
/// normalised.
enum ItemStatus { inProgress, completed, failed, unknown }

/// One item from `GET /history`, parsed **tolerantly** per the table in
/// `05-DATA-SCHEMA.md` §2.3. The hard rules:
/// - [canonicalUrl] is the primary key for all app data.
/// - A missing [filename] stays null; it is **never invented from the
///   title** (trap §6.3).
/// - The `i.ytimg.com` fallback thumbnail is for YouTube **only**;
///   anything else stays imageless, and ArtworkIndex fills it in a layer
///   above.
class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.canonicalUrl,
    this.title,
    this.filename,
    this.uploader,
    this.thumbnail,
    this.progress,
    this.status = ItemStatus.unknown,
    this.rawStatus,
    this.error,
    this.timestamp,
    this.quality,
    this.format,
    this.sizeBytes,
  });

  final String id;

  /// The canonical URL as the server returned it. Deletion and indexing use
  /// this, never the entered URL.
  final String canonicalUrl;
  final String? title;
  final String? filename;
  final String? uploader;
  final String? thumbnail;

  /// 0 to 1, or null when absent.
  final double? progress;
  final ItemStatus status;
  final String? rawStatus;
  final String? error;
  final DateTime? timestamp;
  final String? quality;
  final String? format;

  /// The file's size on the server in bytes if it reported one (`size`),
  /// for sorting and display.
  final int? sizeBytes;

  bool get isDownloading => status == ItemStatus.inProgress;
  bool get isCompleted => status == ItemStatus.completed;
  bool get hasError =>
      status == ItemStatus.failed || (error != null && error!.isNotEmpty);

  /// An error indicating a blocked platform (cookies), which becomes
  /// `PlatformBlockedException` above.
  bool get isPlatformBlocked =>
      error != null && UrlKit.isPlatformBlockedError(error!);

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final url = _str(json['url']) ?? '';

    final rawStatus = _str(json['status']) ?? _str(json['state']);
    final error =
        _str(json['error']) ?? _str(json['msg']) ?? _str(json['message']);

    return HistoryItem(
      id: _str(json['id']) ?? _str(json['_id']) ?? _uuid.v4(),
      canonicalUrl: url,
      title: _str(json['title']) ?? _str(json['name']),
      filename: _str(json['filename']) ?? _str(json['file']),
      uploader: _parseUploader(json),
      thumbnail: _parseThumbnail(json, url),
      progress: _parseProgress(json),
      status: _mapStatus(rawStatus, error),
      rawStatus: rawStatus,
      error: error,
      timestamp: _parseTimestamp(json),
      quality: _str(json['quality']),
      format: _str(json['format']),
      sizeBytes: json['size'] is num ? (json['size'] as num).toInt() : null,
    );
  }

  /// Any value becomes a non-empty string or null; errors can arrive from
  /// the server as a map.
  static String? _str(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _parseUploader(Map<String, dynamic> json) {
    final raw =
        _str(json['uploader']) ??
        _str(json['channel']) ??
        _str(json['creator']) ??
        _str(json['artist']) ??
        _str(json['uploader_id']) ??
        _str(json['channel_id']);
    if (raw == null) return null;
    // Removes the "[videoid]" suffix yt-dlp sometimes appends.
    return raw.replaceFirst(RegExp(r'\s*\[[A-Za-z0-9_-]{6,}\]\s*$'), '').trim();
  }

  static String? _parseThumbnail(Map<String, dynamic> json, String url) {
    var thumb =
        _str(json['thumbnail']) ??
        _str(json['thumb']) ??
        _str(json['thumbnail_url']) ??
        _str(json['thumbnailUrl']);

    if (thumb == null && json['entry'] is Map) {
      final entry = json['entry'] as Map;
      thumb = _str(entry['thumbnail']);
      if (thumb == null && entry['thumbnails'] is List) {
        final list = entry['thumbnails'] as List;
        if (list.isNotEmpty && list.last is Map) {
          thumb = _str((list.last as Map)['url']);
        }
      }
    }
    if (thumb != null) return thumb;

    final videoId = UrlKit.youtubeVideoId(url);
    if (videoId != null) {
      return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    }
    return null; // not YouTube: nothing is invented; ArtworkIndex fills it later.
  }

  static double? _parseProgress(Map<String, dynamic> json) {
    final raw = json['percent'] ?? json['progress'];
    if (raw is! num) return null;
    final value = raw.toDouble();
    return value > 1 ? value / 100 : value;
  }

  static ItemStatus _mapStatus(String? rawStatus, String? error) {
    switch (rawStatus?.toLowerCase()) {
      case 'downloading' || 'pending' || 'running' || 'preparing':
        return ItemStatus.inProgress;
      case 'completed' || 'done' || 'finished':
        return ItemStatus.completed;
      case 'error' || 'failed':
        return ItemStatus.failed;
    }
    if (error != null && error.isNotEmpty) return ItemStatus.failed;
    return ItemStatus.unknown;
  }

  static DateTime? _parseTimestamp(Map<String, dynamic> json) {
    final ts = json['timestamp'];
    if (ts is num) {
      var ms = ts.toInt();
      // Nanoseconds to milliseconds.
      if (ms > 10000000000000) ms = ms ~/ 1000000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (ts != null) return DateTime.tryParse(ts.toString());
    final dt = json['datetime'];
    return dt == null ? null : DateTime.tryParse(dt.toString());
  }
}
