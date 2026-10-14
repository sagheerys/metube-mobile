import 'transcript.dart';

/// Reads SRT and WebVTT into [TranscriptSegment]s.
///
/// Tolerant by design: a malformed cue is skipped, never fatal, because a
/// subtitle file from the open web is not a contract. The text keeps its
/// words and drops everything else — styling tags, positioning, cue
/// numbers.
abstract final class SubtitleParser {
  /// Raised when the reader learns something new, so a transcript read by
  /// an older one can be read again: 2 keeps when each word is said.
  static const version = 2;

  static final _byteOrderMark = String.fromCharCode(0xFEFF);
  static final _timing = RegExp(
    r'^\s*((?:\d+:)?\d{1,2}:\d{2}[,.]\d{1,3})\s*-->\s*'
    r'((?:\d+:)?\d{1,2}:\d{2}[,.]\d{1,3})',
  );
  static final _tag = RegExp(r'<[^>]*>|\{\\[^}]*\}');
  static final _space = RegExp(r'\s+');
  static final _vttBlock = RegExp(r'^(NOTE|STYLE|REGION)\b');

  /// The moment inside an automatic caption's line at which the next word
  /// is said: `over, <00:00:01.693><c>which</c>`.
  static final _wordStamp = RegExp(r'<((?:\d+:)?\d{1,2}:\d{2}[,.]\d{1,3})>');

  /// One reader for both: they differ only in the timing separator and
  /// the WebVTT header, which comes before any timing line and is skipped.
  ///
  /// **A cue runs from its timing line to the next one**, not to the next
  /// blank line. Automatic captions open the first line after a pause
  /// with an empty line above it; cutting cues at blank lines orphaned
  /// that line, which then surfaced in the next cue, one line late — every
  /// line of a song, where each follows a pause.
  static List<TranscriptSegment> parse(String content) {
    final lines = content
        .replaceFirst(_byteOrderMark, '')
        .replaceAll('\r\n', '\n')
        .split('\n');
    final segments = <TranscriptSegment>[];
    // Automatic captions roll: each cue repeats the line before it, so a
    // naive reader stores every sentence twice and search finds it twice.
    String? lastLine;
    (Duration, Duration)? timing;
    final texts = <String>[];

    void flush() {
      if (timing case (final start, final end)) {
        final fresh = <String>[];
        final words = <TranscriptWord>[];
        var timed = false;
        for (final raw in texts) {
          final line = _clean(raw);
          if (line.isEmpty || line == lastLine) continue;
          fresh.add(line);
          lastLine = line;
          final (stamped, lineWords) = _wordsOf(raw, start);
          timed |= stamped;
          words.addAll(lineWords);
        }
        if (fresh.isNotEmpty) {
          segments.add(
            TranscriptSegment(
              start: start,
              end: end,
              text: fresh.join(' '),
              words: timed ? words : null,
            ),
          );
        }
      }
      timing = null;
      texts.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_timing.firstMatch(line) case final match?) {
        flush();
        final start = _duration(match.group(1)!);
        final end = _duration(match.group(2)!);
        if (start != null && end != null) timing = (start, end);
        continue;
      }
      // A cue number or WebVTT identifier names the cue below it.
      if (i + 1 < lines.length && _timing.hasMatch(lines[i + 1])) continue;
      // A WebVTT comment or style block ends the cue before it.
      if (_vttBlock.hasMatch(line) && i > 0 && lines[i - 1].trim().isEmpty) {
        flush();
        continue;
      }
      if (timing != null) texts.add(line);
    }
    flush();
    return segments;
  }

  /// The words of one line, each from the moment it is said. A word before
  /// the first stamp is said as the cue starts; [stamped] is false for a
  /// line with no stamp at all, as in a creator's own subtitles.
  static (bool stamped, List<TranscriptWord> words) _wordsOf(
    String raw,
    Duration start,
  ) {
    final words = <TranscriptWord>[];
    var at = start;
    var stamped = false;
    var from = 0;
    // Whether the text so far ends inside a word, with no space after it.
    var open = false;
    // **Punctuation stamped on its own** (measured on a server's files
    // 2026-10-14): some tracks stamp the comma after "happen" separately,
    // and taken as a word it read "happen , for". A piece with no space
    // between it and the piece before belongs to the word before it.
    void take(String chunk) {
      final text = _decodeEntities(chunk.replaceAll(_tag, ''))
          .replaceAll(_zeroWidth, '');
      if (text.isEmpty) return;
      final glued = open && !text.startsWith(_space);
      open = !_whitespaceEnd.hasMatch(text);
      var first = true;
      for (final word in _clean(text).split(' ')) {
        if (word.isEmpty) continue;
        if (first && glued && words.isNotEmpty) {
          final last = words.removeLast();
          words.add(TranscriptWord(last.start, '${last.text}$word'));
        } else {
          words.add(TranscriptWord(at, word));
        }
        first = false;
      }
    }

    for (final match in _wordStamp.allMatches(raw)) {
      take(raw.substring(from, match.start));
      at = _duration(match.group(1)!) ?? at;
      stamped = true;
      from = match.end;
    }
    take(raw.substring(from));
    return (stamped, words);
  }

  /// Zero-width spaces go too: automatic captions put two after some words
  /// ("AI"), which then read as a word of their own between two others.
  static String _clean(String line) =>
      _decodeEntities(line.replaceAll(_tag, ''))
          .replaceAll(_zeroWidth, '')
          .replaceAll(_space, ' ')
          .trim();

  static final _zeroWidth = String.fromCharCode(0x200B);
  static final _whitespaceEnd = RegExp(r'\s$');

  static String _decodeEntities(String s) => s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');

  /// `01:02:03,450`, `02:03.450` or `1:02:03.4`.
  static Duration? _duration(String stamp) {
    final parts = stamp.split(RegExp('[:,.]'));
    if (parts.length < 3) return null;
    final fraction = parts.removeLast().padRight(3, '0');
    final numbers = [...parts.map(int.tryParse), int.tryParse(fraction)];
    if (numbers.contains(null)) return null;
    final n = numbers.cast<int>();
    final (h, m, s, ms) = n.length == 4
        ? (n[0], n[1], n[2], n[3])
        : (0, n[0], n[1], n[2]);
    return Duration(hours: h, minutes: m, seconds: s, milliseconds: ms);
  }
}
