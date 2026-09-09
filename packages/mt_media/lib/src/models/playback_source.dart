import 'dart:io';

import 'package:mt_core/mt_core.dart';

import 'playlist_item.dart';

/// Where the item is actually played from.
enum PlaybackOrigin { local, stream }

/// A playback source ready for the player: a URL plus headers, since
/// streaming needs Authorization.
class PlaybackSource {
  const PlaybackSource({
    required this.origin,
    required this.uri,
    this.headers = const {},
  });

  final PlaybackOrigin origin;
  final Uri uri;
  final Map<String, String> headers;

  bool get isLocal => origin == PlaybackOrigin.local;

  @override
  String toString() => 'PlaybackSource(${origin.name}, $uri)';
}

/// Everything playback needs from the server: building the file URL and
/// the streaming headers. A deliberately narrow interface, so the player
/// knows neither the rest of the server contract nor the network package.
class ServerStreamEndpoint {
  const ServerStreamEndpoint({required this.buildUrl, required this.headers});

  /// May throw [UnsafeFilenameException] for a malicious filename (rule 9).
  final String Function(String serverFilename) buildUrl;
  final Map<String, String> headers;

  factory ServerStreamEndpoint.fromApi(MeTubeApi api) => ServerStreamEndpoint(
        buildUrl: api.downloadUrl,
        headers: api.streamingHeaders,
      );

  /// No server configured means local files only.
  static ServerStreamEndpoint get none => ServerStreamEndpoint(
        buildUrl: (_) => throw const UnsafeFilenameException(),
        headers: const {},
      );
}

/// **The golden rule:** the local copy if it really exists on disk,
/// otherwise streaming from the server with authentication headers. The
/// position is shared between the two cases because its key is
/// [PlaylistItem.canonicalUrl], not the path.
///
/// A path being present in the index **is not enough**: the file may have
/// been deleted from outside the app, so the disk is checked before
/// preferring it. The checker is injected for testing.
class PlaybackSourceResolver {
  PlaybackSourceResolver({
    required this.endpoint,
    bool Function(String path)? fileExists,
  }) : _fileExists = fileExists ?? _defaultExists;

  /// Refreshable when the server settings change, so a live player picks up
  /// the new URL without rebuilding the session.
  ServerStreamEndpoint endpoint;
  final bool Function(String path) _fileExists;

  static bool _defaultExists(String path) => File(path).existsSync();

  /// null means no valid source: no local file and no valid filename on the
  /// server.
  PlaybackSource? resolve(PlaylistItem item) {
    final local = item.localPath;
    if (local != null && local.isNotEmpty && _fileExists(local)) {
      return PlaybackSource(origin: PlaybackOrigin.local, uri: Uri.file(local));
    }
    final filename = item.serverFilename;
    if (filename == null || filename.isEmpty) return null;
    try {
      return PlaybackSource(
        origin: PlaybackOrigin.stream,
        uri: Uri.parse(endpoint.buildUrl(filename)),
        headers: endpoint.headers,
      );
    } on UnsafeFilenameException {
      return null;
    }
  }
}
