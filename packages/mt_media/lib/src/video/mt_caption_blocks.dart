import 'package:flutter/foundation.dart';

import 'mt_captions.dart';

/// What is on screen at once: a sentence of up to two lines, gathered from
/// lines that follow each other.
///
/// **Automatic captions come in three to five words** a cue, and shown as
/// they come they change every second. Gathered into a sentence that stays
/// put while the spoken word lights up along it, they read like a film's
/// subtitles.
@immutable
class MTCaptionBlock {
  const MTCaptionBlock({
    required this.start,
    required this.until,
    required this.text,
    this.words,
  });

  final Duration start;

  /// Shown up to here: the next sentence, when it follows closely, so the
  /// screen does not blink empty between two; a moment after the last
  /// word, when silence follows.
  final Duration until;
  final String text;
  final List<MTCaptionWord>? words;

  /// About two lines of subtitles.
  static const maxChars = 84;

  /// A pause longer than this starts a new sentence.
  static const pause = Duration(milliseconds: 1500);

  /// How long a sentence stays after its last word when nothing follows.
  static const linger = Duration(milliseconds: 700);

  static final _sentenceEnd = RegExp(r'[.?!؟…]$');

  static List<MTCaptionBlock> group(List<MTCaptionLine> lines) {
    final groups = <List<MTCaptionLine>>[];
    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      final current = groups.isEmpty ? null : groups.last;
      if (current == null) {
        groups.add([line]);
        continue;
      }
      final length = current.fold(0, (n, l) => n + l.text.length + 1);
      final last = current.last;
      final closed =
          _sentenceEnd.hasMatch(last.text.trim()) && length >= maxChars / 2;
      if (line.start - last.end > pause ||
          length + text.length > maxChars ||
          closed) {
        groups.add([line]);
      } else {
        current.add(line);
      }
    }
    return [
      for (var i = 0; i < groups.length; i++)
        _block(groups[i], i + 1 < groups.length ? groups[i + 1].first : null),
    ];
  }

  static MTCaptionBlock _block(List<MTCaptionLine> lines, MTCaptionLine? next) {
    final end = lines.last.end;
    final until = next != null && next.start - end <= pause
        ? next.start
        : end + linger;
    final timed = lines.any((l) => l.words != null);
    return MTCaptionBlock(
      start: lines.first.start,
      until: until,
      text: lines.map((l) => l.text.trim()).join(' '),
      words: timed
          ? [
              for (final line in lines)
                ...line.words ??
                    [
                      for (final word in line.text.trim().split(' '))
                        MTCaptionWord(line.start, word),
                    ],
            ]
          : null,
    );
  }

  /// The sentence shown at [at], if any.
  static int indexAt(List<MTCaptionBlock> blocks, Duration at) {
    var low = 0, high = blocks.length - 1, found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (blocks[mid].start <= at) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (found < 0 || at >= blocks[found].until) return -1;
    return found;
  }

  /// The word being said at [at]: the last that has started.
  int wordAt(Duration at) {
    final words = this.words;
    if (words == null) return -1;
    var index = -1;
    for (var i = 0; i < words.length; i++) {
      if (words[i].start > at) break;
      index = i;
    }
    return index;
  }
}
