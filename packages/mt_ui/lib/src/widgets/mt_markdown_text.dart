import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// **A very small Markdown reader, for text written elsewhere.**
///
/// The release notes come from the GitHub release page, which is Markdown,
/// and the update sheet printed them as they arrived: `**bold**` with its
/// stars, `- ` before every line, `##` before every heading, and link
/// syntax in the middle of a sentence. It read like a text file, in the one
/// place the app asks someone to trust it enough to install something.
///
/// **Not a Markdown package.** A full one is a large dependency, and its
/// job — arbitrary documents — is not this one. What is rendered here is
/// the shape our own release notes take (`CLAUDE.md` §7): headings, bullets,
/// bold, inline code, a small table, links. Anything else is shown as its
/// own text rather than as syntax, which is the failure that matters: an
/// unknown construct must read as a sentence, never as a stray symbol.
///
/// Links are **not tappable**. They were not before either, and a tap
/// target that leaves the app during an install prompt is a decision of its
/// own, not a side effect of tidying text.

/// A run of text inside one line.
@immutable
class MTMdSpan {
  const MTMdSpan(this.text, {this.bold = false, this.code = false});

  final String text;
  final bool bold;
  final bool code;

  @override
  bool operator ==(Object other) =>
      other is MTMdSpan &&
      other.text == text &&
      other.bold == bold &&
      other.code == code;

  @override
  int get hashCode => Object.hash(text, bold, code);

  @override
  String toString() =>
      'MTMdSpan($text${bold ? ', bold' : ''}${code ? ', code' : ''})';
}

enum MTMdKind { paragraph, bullet, heading }

/// One block: a paragraph, a bullet, or a heading of [level] 1 to 6.
@immutable
class MTMdBlock {
  const MTMdBlock(this.kind, this.spans, {this.level = 0});

  final MTMdKind kind;
  final List<MTMdSpan> spans;
  final int level;

  /// The block's text with all emphasis dropped — what a reader sees.
  String get text => spans.map((s) => s.text).join();

  @override
  String toString() => '$kind($level): $text';
}

final RegExp _link = RegExp(r'\[([^\]]*)\]\(([^)\s]*)\)');
final RegExp _emphasis = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
final RegExp _heading = RegExp(r'^(#{1,6})\s+(.*)$');
final RegExp _bullet = RegExp(r'^\s{0,3}[-*+]\s+(.*)$');
final RegExp _rule = RegExp(r'^\s{0,3}([-*_])\1{2,}\s*$');
final RegExp _tableDivider = RegExp(r'^:?-{2,}:?$');

List<MTMdSpan> _spansOf(String line) {
  // A link becomes its own words: the address is no use in a sheet that
  // cannot be tapped, and `[text](https://…)` in the middle of a sentence
  // is worse than either half alone.
  final text = line.replaceAllMapped(_link, (m) {
    final label = m.group(1)!;
    return label.isEmpty ? m.group(2)! : label;
  });
  final spans = <MTMdSpan>[];
  var index = 0;
  for (final match in _emphasis.allMatches(text)) {
    if (match.start > index) {
      spans.add(MTMdSpan(text.substring(index, match.start)));
    }
    final bold = match.group(1);
    spans.add(
      bold != null
          ? MTMdSpan(bold, bold: true)
          : MTMdSpan(match.group(2)!, code: true),
    );
    index = match.end;
  }
  if (index < text.length) spans.add(MTMdSpan(text.substring(index)));
  return spans.isEmpty ? [MTMdSpan(text)] : spans;
}

/// Parses [source] into blocks. Pure, and tested on its own.
List<MTMdBlock> mtParseMarkdown(String source) {
  final blocks = <MTMdBlock>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    // Markdown's soft wrap: lines inside one paragraph are one sentence.
    blocks.add(MTMdBlock(MTMdKind.paragraph, _spansOf(paragraph.join(' '))));
    paragraph.clear();
  }

  for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty || _rule.hasMatch(line)) {
      flush();
      continue;
    }

    final heading = _heading.firstMatch(line);
    if (heading != null) {
      flush();
      blocks.add(
        MTMdBlock(
          MTMdKind.heading,
          _spansOf(heading.group(2)!.trim()),
          level: heading.group(1)!.length,
        ),
      );
      continue;
    }

    if (line.trimLeft().startsWith('|')) {
      flush();
      final cells = [for (final cell in line.split('|')) cell.trim()]
        ..removeWhere((cell) => cell.isEmpty);
      // The `|---|---|` line under a header is punctuation, not content.
      if (cells.isEmpty || cells.every(_tableDivider.hasMatch)) continue;
      blocks.add(MTMdBlock(MTMdKind.bullet, _spansOf(cells.join(' — '))));
      continue;
    }

    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      flush();
      blocks.add(MTMdBlock(MTMdKind.bullet, _spansOf(bullet.group(1)!)));
      continue;
    }

    paragraph.add(line.startsWith('>') ? line.substring(1).trim() : line);
  }
  flush();
  return blocks;
}

/// Renders [source] with [mtParseMarkdown].
class MTMarkdownText extends StatelessWidget {
  const MTMarkdownText({required this.source, this.style, super.key});

  final String source;

  /// The body style; headings take their weight and size from it.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final body =
        style ?? Theme.of(context).textTheme.bodySmall!.copyWith(color: p.ink2);
    final blocks = mtParseMarkdown(source);

    TextSpan spanOf(MTMdSpan span, TextStyle base) => TextSpan(
      text: span.text,
      style: span.code
          ? base.copyWith(color: p.ink3, letterSpacing: 0.2)
          : (span.bold ? base.copyWith(fontWeight: FontWeight.w700) : base),
    );

    Widget line(MTMdBlock block, TextStyle base) => Text.rich(
      TextSpan(children: [for (final s in block.spans) spanOf(s, base)]),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final block in blocks) ...[
          if (block != blocks.first)
            SizedBox(
              height: block.kind == MTMdKind.heading ? MTSpace.sm : MTSpace.xxs,
            ),
          switch (block.kind) {
            MTMdKind.heading => line(
              block,
              body.copyWith(
                color: p.ink,
                fontWeight: FontWeight.w700,
                fontSize: (body.fontSize ?? 13) + (block.level <= 2 ? 2 : 1),
              ),
            ),
            MTMdKind.bullet => Padding(
              padding: const EdgeInsetsDirectional.only(start: MTSpace.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•', style: body),
                  const SizedBox(width: MTSpace.xs),
                  Expanded(child: line(block, body)),
                ],
              ),
            ),
            MTMdKind.paragraph => line(block, body),
          },
        ],
      ],
    );
  }
}
