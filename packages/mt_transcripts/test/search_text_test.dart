import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

/// Arabic letters are written by code point so the test reads the same in
/// any editor; the comment beside each says what it is.
String ar(List<int> codes) => String.fromCharCodes(codes);

void main() {
  test('every alef form reads as a bare alef', () {
    const alef = 0x0627;
    for (final form in [0x0622, 0x0623, 0x0625, 0x0671]) {
      expect(SearchText.fold(ar([form])), ar([alef]));
    }
  });

  test('teh marbuta, alef maksura and hamza seats fold to their bases', () {
    expect(SearchText.fold(ar([0x0629])), ar([0x0647])); // teh marbuta -> heh
    expect(SearchText.fold(ar([0x0649])), ar([0x064A])); // maksura -> yeh
    expect(SearchText.fold(ar([0x0624])), ar([0x0648])); // waw hamza -> waw
    expect(SearchText.fold(ar([0x0626])), ar([0x064A])); // yeh hamza -> yeh
  });

  test('vowel marks and tatweel vanish', () {
    // kaf-fatha-tatweel-teh-kasra-alef-beh: a stretched, vowelled "kitab".
    final marked = ar([0x0643, 0x064E, 0x0640, 0x062A, 0x0650, 0x0627, 0x0628]);
    expect(SearchText.fold(marked), ar([0x0643, 0x062A, 0x0627, 0x0628]));
  });

  test('Arabic-Indic digits read as ASCII ones', () {
    expect(SearchText.fold(ar([0x0662, 0x0660, 0x0662, 0x0666])), '2026');
    expect(SearchText.fold(ar([0x06F1, 0x06F9])), '19');
  });

  test('case, punctuation of both scripts and spacing are folded', () {
    expect(SearchText.fold('  Hello,   WORLD!  '), 'hello world');
    expect(SearchText.fold('a${ar([0x060C])}b${ar([0x061F])}'), 'a b');
    expect(SearchText.fold('wait… what'), 'wait what');
  });

  group('matchRanges', () {
    test('finds each word where the original text has it', () {
      const line = 'We keep a Backup on the SERVER.';
      final ranges = SearchText.matchRanges(line, 'server backup');
      expect(
        [for (final (a, b) in ranges) line.substring(a, b)],
        ['Backup', 'SERVER'],
      );
    });

    test('a bare alef lights up the word written with hamza and marks', () {
      // "ahlan" written alef-hamza, fatha on the lam; typed plain.
      final written = ar([0x0623, 0x0647, 0x0644, 0x064E, 0x0627]);
      final typed = ar([0x0627, 0x0647, 0x0644, 0x0627]);
      final ranges = SearchText.matchRanges('say $written now', typed);
      expect(ranges, [(4, 4 + written.length)]);
    });

    test('overlapping words merge into one range', () {
      expect(SearchText.matchRanges('backups', 'back backup'), [(0, 6)]);
    });

    test('nothing to find gives nothing to light', () {
      expect(SearchText.matchRanges('hello', 'bye'), isEmpty);
      expect(SearchText.matchRanges('hello', '  '), isEmpty);
    });
  });

  test('single letters count only when they are the whole query', () {
    expect(SearchText.wordsOf('a backup'), ['backup']);
    expect(SearchText.wordsOf('a'), ['a']);
  });
}
