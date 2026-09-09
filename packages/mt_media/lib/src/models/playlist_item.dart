/// The unified item for every player, audio, video and reels. **A lesson
/// from the old Super:** the screens carried two conflicting classes for
/// the same concept, so play modes drifted apart. The single key is
/// [canonicalUrl] (`05-DATA-SCHEMA.md` §5.5), so a stream and a local copy
/// share the same resume position.
class PlaylistItem {
  const PlaylistItem({
    required this.canonicalUrl,
    required this.title,
    this.uploader,
    this.artworkUrl,
    this.localPath,
    this.serverFilename,
    this.isAudio = false,
    this.duration,
    this.aspectRatio,
  });

  /// The canonical URL from `/history`: the key for positions, tags and
  /// favourites.
  final String canonicalUrl;
  final String title;
  final String? uploader;
  final String? artworkUrl;

  /// The local copy's path when one exists; it takes priority under the
  /// golden rule.
  final String? localPath;

  /// The filename on the server, the fallback streaming source.
  final String? serverFilename;
  final bool isAudio;

  /// The duration if known, from an earlier play or from the index.
  /// Required for the shorts path.
  final Duration? duration;

  /// The aspect ratio if known; below 1 means a portrait video.
  final double? aspectRatio;

  bool get hasLocal => localPath != null && localPath!.isNotEmpty;
  bool get hasServer => serverFilename != null && serverFilename!.isNotEmpty;
  bool get isPlayable => hasLocal || hasServer;

  /// A short portrait video enters the shorts path in the reels player.
  /// Unknown, with no duration or no ratio, is **not** short. No guessing.
  bool get isShortForm =>
      !isAudio &&
      duration != null &&
      duration! <= const Duration(minutes: 3) &&
      aspectRatio != null &&
      aspectRatio! < 1;

  PlaylistItem copyWith({
    String? title,
    String? uploader,
    String? artworkUrl,
    String? localPath,
    String? serverFilename,
    bool? isAudio,
    Duration? duration,
    double? aspectRatio,
  }) => PlaylistItem(
    canonicalUrl: canonicalUrl,
    title: title ?? this.title,
    uploader: uploader ?? this.uploader,
    artworkUrl: artworkUrl ?? this.artworkUrl,
    localPath: localPath ?? this.localPath,
    serverFilename: serverFilename ?? this.serverFilename,
    isAudio: isAudio ?? this.isAudio,
    duration: duration ?? this.duration,
    aspectRatio: aspectRatio ?? this.aspectRatio,
  );

  Map<String, dynamic> toJson() => {
    'url': canonicalUrl,
    'title': title,
    if (uploader != null) 'uploader': uploader,
    if (artworkUrl != null) 'artwork': artworkUrl,
    if (localPath != null) 'localPath': localPath,
    if (serverFilename != null) 'filename': serverFilename,
    'isAudio': isAudio,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    if (aspectRatio != null) 'aspectRatio': aspectRatio,
  };

  /// Tolerant parsing: an item with no URL is invalid and is dropped above
  /// as null.
  static PlaylistItem? fromJson(Map<String, dynamic> json) {
    final url = json['url']?.toString() ?? '';
    if (url.isEmpty) return null;
    final ms = json['durationMs'];
    final ratio = json['aspectRatio'];
    return PlaylistItem(
      canonicalUrl: url,
      title: json['title']?.toString() ?? url,
      uploader: json['uploader']?.toString(),
      artworkUrl: json['artwork']?.toString(),
      localPath: json['localPath']?.toString(),
      serverFilename: json['filename']?.toString(),
      isAudio: json['isAudio'] == true,
      duration: ms is num ? Duration(milliseconds: ms.toInt()) : null,
      aspectRatio: ratio is num ? ratio.toDouble() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlaylistItem && other.canonicalUrl == canonicalUrl;

  @override
  int get hashCode => canonicalUrl.hashCode;

  @override
  String toString() => 'PlaylistItem($title)';
}
