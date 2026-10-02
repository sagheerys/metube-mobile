/// **One language of the release notes.**
///
/// A release page is written in English first, then a short Arabic summary
/// below a horizontal rule (`---`). The update sheet shows the page as it
/// is; "what's new", read once right after an update, shows the half the
/// reader reads: the Arabic summary under an Arabic interface, and the
/// English part otherwise.
///
/// The English part also loses its "Which file" section, which tells a
/// visitor which download to pick and means nothing to someone who has
/// already installed it.
///
/// Notes without the rule, or whose second half is not Arabic, are returned
/// whole: the worst case is showing more than needed, never less.
///
/// With [app] (`lite` or `super`), the bullets written for the other app
/// are left out: one page serves both apps, and a Lite user read about
/// channels and cookies Lite does not have. A bullet belongs to one app
/// when it opens with its name ("MeTube Lite finishes…", "Super —") or
/// closes with it ("MeTube Super.", "(Super)", "Super only."), the way
/// every release page is written. Anything unmarked is for both and stays.
String mtReleaseNotesFor(String body, {required bool arabic, String? app}) {
  final notes = _language(body, arabic: arabic);
  final other = switch (app?.toLowerCase()) {
    'lite' => 'super',
    'super' => 'lite',
    _ => null,
  };
  return other == null ? notes : _withoutApp(notes, other);
}

String _language(String body, {required bool arabic}) {
  final lines = body.replaceAll('\r\n', '\n').split('\n');
  final rule = lines.indexWhere((line) => line.trim() == '---');
  if (rule < 0) return body.trim();
  final english = lines.sublist(0, rule).join('\n').trim();
  final other = lines.sublist(rule + 1).join('\n').trim();
  if (!_arabicLetter.hasMatch(other)) return body.trim();
  if (arabic) return other.replaceFirst(_arabicLabel, '').trim();
  return _withoutSection(english, 'which file');
}

final _arabicLetter = RegExp('[؀-ۿ]');

/// The "In Arabic:" lead-in, which says nothing once only Arabic is shown.
final _arabicLabel = RegExp(r'^\*\*بالعربية:?\*\*:?\s*');

final _heading = RegExp(r'^#{1,6}\s+(.*)$');

/// Drops the section titled [title], up to the next heading.
String _withoutSection(String text, String title) {
  final out = <String>[];
  var skipping = false;
  for (final line in text.split('\n')) {
    final heading = _heading.firstMatch(line.trim());
    if (heading != null) {
      skipping = heading.group(1)!.trim().toLowerCase() == title;
    }
    if (!skipping) out.add(line);
  }
  return out.join('\n').trim();
}

final _bullet = RegExp(r'^\s*[-*]\s+');
final _continuation = RegExp(r'^\s{2,}\S');
final _blankRun = RegExp(r'\n{3,}');
final _trailingEmphasis = RegExp(r'[*_\s]+$');

/// A line that introduces a list: a Markdown heading, or a paragraph that
/// is bold and ends in a colon, as the Arabic half writes its subheadings.
bool _isLead(String line) {
  final t = line.trim();
  return _heading.hasMatch(t) ||
      (t.startsWith('**') && (t.endsWith(':**') || t.endsWith('**:')));
}

/// Drops every bullet written for [app], then any lead left with nothing
/// under it.
String _withoutApp(String text, String app) {
  final opens = RegExp(
    r'^(?:\*\*)?(?:metube\s+' + app + r'\b|' + app + r'\s*(?::|—|-))',
    caseSensitive: false,
  );
  final closes = RegExp(
    r'(?:metube\s+' +
        app +
        r'|\(' +
        app +
        r'\)|' +
        app +
        r'\s+only|' +
        app +
        r'\s+وحده|' +
        app +
        r'\s+فقط)[.)]*\s*$',
    caseSensitive: false,
  );
  // Bullets with their continuation lines, so a bullet is judged whole.
  final blocks = <List<String>>[];
  for (final line in text.split('\n')) {
    final continues =
        blocks.isNotEmpty &&
        _bullet.hasMatch(blocks.last.first) &&
        _continuation.hasMatch(line);
    if (continues) {
      blocks.last.add(line);
    } else {
      blocks.add([line]);
    }
  }
  bool foreign(List<String> block) {
    if (!_bullet.hasMatch(block.first)) return false;
    final whole = block
        .map((line) => line.trim())
        .join(' ')
        .replaceFirst(_bullet, '');
    // A bullet written all in bold ends in `**`: the marker sits before it.
    final bare = whole.replaceFirst(_trailingEmphasis, '');
    return opens.hasMatch(whole) || closes.hasMatch(bare);
  }

  final kept = [
    for (final block in blocks)
      if (!foreign(block)) block,
  ];
  // A lead whose list emptied would introduce nothing.
  final out = <String>[];
  for (var i = 0; i < kept.length; i++) {
    final block = kept[i];
    if (_isLead(block.first)) {
      var j = i + 1;
      while (j < kept.length && kept[j].first.trim().isEmpty) {
        j++;
      }
      if (j == kept.length || _isLead(kept[j].first)) continue;
    }
    out.addAll(block);
  }
  return out.join('\n').replaceAll(_blankRun, '\n\n').trim();
}
