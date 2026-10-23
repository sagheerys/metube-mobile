import 'url_kit.dart';

/// **Where a finished file lives on the server**, as one string the apps
/// store and hand back to the client.
///
/// MeTube reports a file in two parts: `folder`, the download's own folder
/// below the download directory, and `filename`, relative to that folder,
/// which itself holds subfolders when `OUTPUT_TEMPLATE` writes them
/// (`%(channel)s/%(title)s.%(ext)s`). Audio downloads are served from a
/// second route, `audio_download/`, because `AUDIO_DOWNLOAD_DIR` can be a
/// different directory. MeTube's own page joins the three the same way.
///
/// The string is the relative path, folder first. An audio download is
/// marked by a leading [_audioMark]: a name from the server is relative and
/// never starts with `/` (the guard refuses it), so the mark cannot be
/// mistaken for a real path. A plain name stored by app versions without
/// folder support still means a file at the top of `download/`.
abstract final class ServerPath {
  static const _audioMark = '/audio_download/';

  /// The stored form of a `/history` item's file, or null without a
  /// filename (one is never invented).
  ///
  /// **A `..` that climbs out of the folder is resolved, not refused.** A
  /// server whose `YTDL_OPTIONS` carries an absolute `outtmpl` writes every
  /// file to the top of the downloads whatever folder was asked for, and
  /// MeTube then reports it relative to that folder: `Kids/../clip.webm`
  /// for `clip.webm` (measured 2026-10-22). Resolving it here plays the
  /// file the server really has. A path that would climb above the
  /// download directory keeps its `..` and the guard refuses it.
  static String? of({String? folder, String? filename, bool audio = false}) {
    if (filename == null || filename.isEmpty) return null;
    final segments = <String>[];
    for (final segment in [
      ...(folder ?? '').split('/').where((s) => s.isNotEmpty),
      ...filename.split('/'),
    ]) {
      if (segment == '..' && segments.isNotEmpty && segments.last != '..') {
        segments.removeLast();
      } else {
        segments.add(segment);
      }
    }
    final relative = segments.join('/');
    return audio ? '$_audioMark$relative' : relative;
  }

  /// **A folder the server will take**, typed or picked: every segment
  /// trimmed, empty, `.` and `..` segments and NUL dropped, a backslash read
  /// as a separator. Empty means the top. Nested folders stay nested
  /// (`Ai/Lessons`), which MeTube creates at any depth.
  static String cleanFolder(String raw) => raw
      .replaceAll('\u0000', '')
      .split(RegExp(r'[/\\]'))
      .map((segment) => segment.trim())
      .where((s) => s.isNotEmpty && s != '.' && s != '..')
      .join('/');

  /// Served from `audio_download/` rather than `download/`.
  static bool isAudio(String path) => path.startsWith(_audioMark);

  /// The path below its route, without the audio mark.
  static String relative(String path) =>
      isAudio(path) ? path.substring(_audioMark.length) : path;

  /// The traversal guard, applied to the path below its route.
  static bool isSafe(String path) =>
      UrlKit.isSafeServerFilename(relative(path));

  /// The URL path below the server's base, every segment encoded on its
  /// own so the slashes between folders survive and an Arabic or bracketed
  /// name does not break the path.
  static String urlPath(String path) {
    final route = isAudio(path) ? 'audio_download' : 'download';
    final encoded = relative(path)
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    return '$route/$encoded';
  }

  /// The file's own name, without any folder.
  static String basename(String path) => relative(path).split('/').last;

  /// The folder the file sits in below its route, empty at the top.
  static String folderOf(String path) {
    final rel = relative(path);
    final slash = rel.lastIndexOf('/');
    return slash < 0 ? '' : rel.substring(0, slash);
  }
}
