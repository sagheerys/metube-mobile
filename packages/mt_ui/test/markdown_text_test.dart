import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The release notes, as the update sheet shows them** (parked
/// 2026-09-19, fixed 2026-09-20).
///
/// They arrive from the GitHub release page as Markdown and were printed
/// as they came: stars around every bold phrase, a dash before every line,
/// hashes before every heading, and `[text](https://…)` mid-sentence — in
/// the one screen that asks someone to trust the app with an install.
///
/// The text below is the shape `CLAUDE.md` §7 requires of every release
/// page, so these are the constructs that actually turn up.
void main() {
  const notes = '''
Installs over the previous version and keeps your settings and library.

## Fixed

- **A Reddit link now finishes** instead of hanging at nothing.
- Cancelling no longer leaves it running on the server.

### Which file

| App | File |
|---|---|
| Lite | `MeTube-Lite-v2.2.0.apk` |

Full list: [CHANGELOG](https://github.com/x/y/blob/main/CHANGELOG.md)

---

## بالعربية

- **رابط رديت** صار يكتمل.
''';

  List<MTMdBlock> parsed() => mtParseMarkdown(notes);

  group('what a reader sees', () {
    test('no syntax survives into the text', () {
      final text = parsed().map((b) => b.text).join('\n');
      for (final syntax in ['**', '##', '](', '|---|', '---']) {
        expect(text.contains(syntax), isFalse, reason: syntax);
      }
      // And nothing of the content is lost with it.
      expect(text, contains('A Reddit link now finishes'));
      expect(text, contains('رابط رديت'));
      expect(text, contains('CHANGELOG'));
    });

    test('a heading is a heading, and keeps its level', () {
      final headings = parsed().where((b) => b.kind == MTMdKind.heading);
      expect(headings.map((b) => (b.level, b.text)), [
        (2, 'Fixed'),
        (3, 'Which file'),
        (2, 'بالعربية'),
      ]);
    });

    test('bold and code survive as emphasis rather than as characters', () {
      final bold = [
        for (final block in parsed())
          for (final span in block.spans)
            if (span.bold) span.text,
      ];
      expect(bold, contains('A Reddit link now finishes'));
      expect(bold, contains('رابط رديت'));

      final code = [
        for (final block in parsed())
          for (final span in block.spans)
            if (span.code) span.text,
      ];
      expect(code, ['MeTube-Lite-v2.2.0.apk']);
    });

    test('a link becomes its words; the address is dropped because nothing '
        'here can be tapped', () {
      final text = parsed().map((b) => b.text).join('\n');
      expect(text, contains('Full list: CHANGELOG'));
      expect(text.contains('https://github.com'), isFalse);
    });

    test('a table row becomes one readable line, and its divider row '
        'disappears', () {
      final lines = parsed().map((b) => b.text).toList();
      expect(lines, contains('App — File'));
      expect(lines, contains('Lite — MeTube-Lite-v2.2.0.apk'));
      expect(lines.any((l) => l.contains('-')), isTrue);
      expect(lines.where((l) => l.trim() == '—').isEmpty, isTrue);
    });

    test('a horizontal rule leaves nothing behind', () {
      expect(parsed().any((b) => b.text.trim().isEmpty), isFalse);
    });
  });

  group('text that is not Markdown at all', () {
    test('plain prose is one paragraph per blank line, with soft wraps '
        'joined', () {
      final blocks = mtParseMarkdown('one\ntwo\n\nthree');
      expect(blocks.map((b) => b.text), ['one two', 'three']);
      expect(blocks.every((b) => b.kind == MTMdKind.paragraph), isTrue);
    });

    test('an unclosed star is text, not syntax: unknown constructs must '
        'read as sentences', () {
      final blocks = mtParseMarkdown('a **b and c');
      expect(blocks.single.text, 'a **b and c');
      expect(blocks.single.spans.any((s) => s.bold), isFalse);
    });

    test('empty in, empty out', () {
      expect(mtParseMarkdown(''), isEmpty);
      expect(mtParseMarkdown('\n\n   \n'), isEmpty);
    });
  });

  testWidgets('it renders, in both languages and at every size', (
    tester,
  ) async {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(child: MTMarkdownText(source: notes)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MTMarkdownText), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
