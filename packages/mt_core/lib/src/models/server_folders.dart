import '../urls/server_path.dart';

/// **The folders a server would save into**, as its live channel lists
/// them when a client connects (`custom_dirs`): every folder below the
/// download directory, empty ones included, which `/history` cannot show.
///
/// Audio has its own list because `AUDIO_DOWNLOAD_DIR` may be another
/// directory; on most servers the two are the same.
class ServerFolders {
  const ServerFolders({
    this.enabled = true,
    this.video = const [],
    this.audio = const [],
  });

  /// A server with `CUSTOM_DIRS` off refuses any folder.
  const ServerFolders.disabled() : this(enabled: false);

  final bool enabled;
  final List<String> video;
  final List<String> audio;

  List<String> of({required bool audio}) => audio ? this.audio : video;

  /// The event's payload, `{"download_dir": [...], "audio_download_dir":
  /// [...]}`, with the top (`""`) and anything unusable left out.
  static ServerFolders? fromJson(dynamic decoded) {
    if (decoded is! Map) return null;
    List<String> list(dynamic raw) => {
      if (raw is List)
        for (final entry in raw)
          if (entry is String && ServerPath.cleanFolder(entry).isNotEmpty)
            ServerPath.cleanFolder(entry),
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final video = list(decoded['download_dir']);
    final audio = decoded.containsKey('audio_download_dir')
        ? list(decoded['audio_download_dir'])
        : video;
    return ServerFolders(video: video, audio: audio);
  }
}
