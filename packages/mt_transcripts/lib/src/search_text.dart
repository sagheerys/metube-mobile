/// Folds text so that a search matches what was **said**, not how a
/// subtitle file happened to spell it.
///
/// Arabic is written with many optional marks and interchangeable letter
/// forms: a speech recogniser writes one alef with a hamza, the person
/// searching types a bare one; one track writes a word with its vowel
/// marks, another without. Without folding, the search fails exactly where
/// Arabic readers expect it to work. Both the stored text and the query go
/// through [fold], so the two always meet in the same form.
abstract final class SearchText {
  /// Lower-cased, marks removed, letter variants unified, digits in ASCII,
  /// runs of spaces collapsed.
  static String fold(String input) => _fold(input).text;

  /// Where each word of [query] appears in [original], as ranges of
  /// [original] itself, for highlighting what was found.
  ///
  /// Found in the folded text and mapped back, so a word typed without
  /// hamza lights up where the subtitles wrote it with one. Overlapping
  /// ranges are merged and returned in order.
  static List<(int, int)> matchRanges(String original, String query) {
    final words = wordsOf(query);
    if (words.isEmpty) return const [];
    final folded = _fold(original);
    final ranges = <(int, int)>[];
    for (final word in words) {
      var at = folded.text.indexOf(word);
      while (at >= 0) {
        ranges.add((folded.starts[at], folded.ends[at + word.length - 1]));
        at = folded.text.indexOf(word, at + word.length);
      }
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final range in ranges) {
      if (merged.isNotEmpty && range.$1 <= merged.last.$2) {
        final last = merged.removeLast();
        merged.add((last.$1, range.$2 > last.$2 ? range.$2 : last.$2));
      } else {
        merged.add(range);
      }
    }
    return merged;
  }

  /// The folded words of a query that are worth searching for: a single
  /// letter matches nearly everything, so it counts only when it is the
  /// whole query.
  static List<String> wordsOf(String query) {
    final all = fold(query).split(' ').where((w) => w.isNotEmpty).toList();
    final meaningful = all.where((w) => w.length >= 2).toList();
    return meaningful.isNotEmpty ? meaningful : all;
  }

  /// The folded text, with where each of its characters came from in the
  /// original, so a match can be mapped back for display.
  static _Folded _fold(String input) {
    final out = StringBuffer();
    final starts = <int>[], ends = <int>[];
    var lastWasSpace = true; // drops leading spaces
    var offset = 0;
    for (final rune in input.runes) {
      final width = rune > 0xFFFF ? 2 : 1;
      final begin = offset;
      offset += width;
      final lower = String.fromCharCode(rune).toLowerCase().runes.first;
      if (_isDroppedMark(lower)) continue;
      final mapped = _letterVariants[lower] ?? _digit(lower) ?? lower;
      if (mapped == 0x20 || _isSeparator(mapped)) {
        if (!lastWasSpace) {
          out.writeCharCode(0x20);
          starts.add(begin);
          ends.add(offset);
        }
        lastWasSpace = true;
        continue;
      }
      out.writeCharCode(mapped);
      // One entry per code unit written, so indexes into the text line up
      // even past the basic plane (an emoji in a title).
      for (var unit = 0; unit < (mapped > 0xFFFF ? 2 : 1); unit++) {
        starts.add(begin);
        ends.add(offset);
      }
      lastWasSpace = false;
    }
    var text = out.toString();
    if (text.endsWith(' ')) {
      text = text.substring(0, text.length - 1);
      starts.removeLast();
      ends.removeLast();
    }
    return _Folded(text, starts, ends);
  }

  /// Arabic vowel marks (fathatan to sukun, and the extended marks after
  /// them), the superscript alef, and the tatweel that only stretches a
  /// word on the page.
  static bool _isDroppedMark(int rune) =>
      (rune >= 0x064B && rune <= 0x065F) || rune == 0x0670 || rune == 0x0640;

  /// Punctuation of both scripts reads as a word break, so a phrase that
  /// straddles a comma in the subtitles is still found.
  static bool _isSeparator(int rune) =>
      rune == 0x0009 ||
      rune == 0x000A ||
      rune == 0x060C || // Arabic comma
      rune == 0x061B || // Arabic semicolon
      rune == 0x061F || // Arabic question mark
      rune == 0x06D4 || // Arabic full stop
      (rune >= 0x21 && rune <= 0x2F) ||
      (rune >= 0x3A && rune <= 0x40) ||
      (rune >= 0x5B && rune <= 0x60) ||
      (rune >= 0x7B && rune <= 0x7E) ||
      rune == 0x2026; // ellipsis

  static const Map<int, int> _letterVariants = {
    0x0622: 0x0627, // alef with madda -> alef
    0x0623: 0x0627, // alef with hamza above -> alef
    0x0625: 0x0627, // alef with hamza below -> alef
    0x0671: 0x0627, // alef wasla -> alef
    0x0649: 0x064A, // alef maksura -> yeh
    0x0629: 0x0647, // teh marbuta -> heh
    0x0624: 0x0648, // waw with hamza -> waw
    0x0626: 0x064A, // yeh with hamza -> yeh
    0x06CC: 0x064A, // Farsi yeh -> yeh
    0x06A9: 0x0643, // keheh -> kaf
  };

  /// Arabic-Indic and extended digits read as the ASCII ones, so "2026"
  /// finds a year spoken and subtitled in either script.
  static int? _digit(int rune) {
    if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
    if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0 + 0x30;
    return null;
  }
}

class _Folded {
  const _Folded(this.text, this.starts, this.ends);

  final String text;

  /// For each character of [text], its span in the original string.
  final List<int> starts;
  final List<int> ends;
}
