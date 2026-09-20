import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **A name the app did not write, inside a sentence it did** (field report
/// 2026-09-20: "قناة جديدة · 5 minutes ago" came apart, and so did the
/// "Unfollow …?" dialog).
///
/// The interface has one direction and the name has its own. Where the two
/// meet, the characters between them — the separator, the question mark,
/// the brackets — belong to neither until something says so. `mtName` says
/// so, by isolating the name and taking its direction from its own first
/// strong character.
void main() {
  const arabicChannel = 'قناة جديدة';
  const latinChannel = 'Veritasium';

  group('mtName', () {
    test('it wraps a name in a first-strong isolate, whatever its '
        'language', () {
      for (final name in [arabicChannel, latinChannel, '日本語', '#وسم']) {
        final wrapped = mtName(name);
        expect(wrapped.startsWith(mtFirstStrongIsolate), isTrue, reason: name);
        expect(wrapped.endsWith(mtPopIsolate), isTrue, reason: name);
        expect(
          wrapped.substring(1, wrapped.length - 1),
          name,
          reason: 'ولا يغيّر الاسم نفسه بحرف',
        );
      }
    });

    test('an empty or missing name stays empty: an isolate around nothing '
        'is two invisible characters that break an isEmpty check further '
        'down', () {
      expect(mtName(null), '');
      expect(mtName(''), '');
    });

    test('it is not the LTR run, which is for clocks and fractions: that '
        'one would force an Arabic channel to read left to right', () {
      expect(mtName(arabicChannel).startsWith(mtLtrIsolate), isFalse);
      expect(mtLtrRun('2 / 40').startsWith(mtLtrIsolate), isTrue);
    });
  });

  group('mtMetaLine', () {
    test('every part is isolated, and the separator belongs to the '
        'sentence', () {
      final line = mtMetaLine([arabicChannel, '5 minutes ago']);
      expect(line, '${mtName(arabicChannel)} · ${mtName("5 minutes ago")}');
      // The separator itself is outside both isolates, which is what lets
      // the interface's direction place it.
      expect(line.contains('$mtPopIsolate · $mtFirstStrongIsolate'), isTrue);
    });

    test('and the reverse pairing, which is the same defect seen from the '
        'Arabic interface', () {
      final line = mtMetaLine([latinChannel, 'منذ ٥ دقائق']);
      expect(line.contains('$mtPopIsolate · $mtFirstStrongIsolate'), isTrue);
    });

    test('a missing part is dropped rather than leaving a stray '
        'separator', () {
      expect(mtMetaLine([arabicChannel, null]), mtName(arabicChannel));
      expect(mtMetaLine([null, '']), '');
      expect(
        mtMetaLine([null, latinChannel, '', 'x']),
        '${mtName(latinChannel)} · ${mtName("x")}',
      );
    });

    test('one part alone carries no separator at all', () {
      expect(mtMetaLine([latinChannel]).contains('·'), isFalse);
    });
  });
}
