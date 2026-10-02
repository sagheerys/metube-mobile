/// The names in the server's download folder, from its directory index.
///
/// A server with `DOWNLOAD_DIRS_INDEXABLE` answers `GET /download/` with a
/// plain HTML index, one `<a href="/download/…">` per entry, the name
/// percent-encoded. Only the names are kept: what the page looks like
/// around them is the web framework's business and may change.
///
/// Needed because YouTube no longer names every subtitle track by its
/// language alone: on a clip with several audio tracks the original
/// tracks carry a suffix (`en-nP7-2PuUl7o`, measured 2026-10-03), which
/// nothing can compute from the language asked for. The files are found
/// by prefix among the names instead.
class SidecarListing {
  const SidecarListing(this.names);

  /// Every file name in the folder, decoded.
  final Set<String> names;

  static final _href = RegExp(r'href="/download/([^"]+)"');

  static SidecarListing parse(String html) => SidecarListing({
    for (final match in _href.allMatches(html)) ?_decode(match.group(1)!),
  });

  static String? _decode(String raw) {
    try {
      return Uri.decodeComponent(raw);
    } on ArgumentError {
      return null; // not ours to read, whatever it is
    }
  }

  /// The subtitle files written beside the media file [filename], with the
  /// language label of each: `clip.en-orig.vtt` beside `clip.mp4` is
  /// `('en-orig', 'clip.en-orig.vtt')`.
  List<(String label, String name)> besides(String filename) {
    final stem = '${stemOf(filename)}.';
    return [
      for (final name in names)
        if (name.startsWith(stem) &&
            (name.endsWith('.vtt') || name.endsWith('.srt')))
          if (name.substring(stem.length, name.length - 4) case final label
              when label.isNotEmpty && !label.contains('.'))
            (label, name),
    ];
  }

  /// The media filename without its extension, as yt-dlp derives it.
  static String stemOf(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot <= 0 ? filename : filename.substring(0, dot);
  }
}
