/// The first sentence of a reason the server gave, for a phone screen.
///
/// yt-dlp writes several lines behind an `ERROR:` and an `[extractor]` tag,
/// then often the video id ("ERROR: [youtube] abc: Video unavailable\n…");
/// on a phone only that first sentence says anything, and the bracketed tag
/// is reordered to the far end of an Arabic line. Returns [raw] itself,
/// trimmed, when stripping would leave nothing.
String serverReason(String raw) {
  final lines = raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  if (lines.isEmpty) return raw.trim();
  final first = lines.first;
  final reason = first
      .replaceFirst(RegExp(r'^ERROR:\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^\[[^\]]+\]\s*([\w-]+:\s+)?'), '')
      .trim();
  return reason.isEmpty ? first : reason;
}
