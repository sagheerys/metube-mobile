import 'package:flutter/widgets.dart';

/// **Direction isolation for numbers inside Arabic text.**
///
/// Arabic runs right to left, and neutral characters (`/`, `-`, `#`)
/// attach to the wrong end of a numeric phrase, inverting its meaning.
/// Measured on a real device 2026-09-05: "2 / 40" in reels rendered as
/// "40 / 2", and "-50:49" rendered as "50:49-".
///
/// `\u2066` (LRI) and `\u2069` (PDI) isolate the run so it reads left to
/// right whatever the surrounding paragraph does. No `Directionality`
/// widget to wrap, and no effect at all in English.
String mtLtrRun(String text) => '\u2066$text\u2069';

/// The opening isolate character, for tests and for callers that build the
/// string themselves.
const String mtLtrIsolate = '\u2066';
const String mtPopIsolate = '\u2069';

/// **Isolation for a name the app did not write** — a channel, an uploader,
/// a playlist, a tag, a title.
///
/// [mtLtrRun] forces left to right, which is right for a clock or a
/// fraction and wrong here: the name decides its own direction. `\u2068`
/// (FSI) takes the direction from the **first strong character in the name
/// itself**, so an Arabic channel reads right to left and an English one
/// left to right, whichever language the interface is in.
///
/// Field report 2026-09-20: an Arabic channel beside an English "5 minutes
/// ago" came apart — the separator and the neutral characters between the
/// two runs belong to whichever side wins, and with an unisolated name
/// there is no defined answer. Isolated, the separator belongs to the
/// sentence and the name to itself.
///
/// Empty in, empty out: an isolate around nothing is two invisible
/// characters that break `isEmpty` checks downstream.
String mtName(String? name) => (name == null || name.isEmpty)
    ? ''
    : '$mtFirstStrongIsolate$name$mtPopIsolate';

/// The first-strong isolate, for callers that assemble their own string.
const String mtFirstStrongIsolate = '\u2068';

/// A "a · b · c" line whose parts are each isolated, for the meta line
/// under a title. Empty parts are dropped rather than leaving a stray
/// separator.
String mtMetaLine(List<String?> parts) => [
  for (final part in parts)
    if (part != null && part.isNotEmpty) mtName(part),
].join(' \u00b7 ');

final _letter = RegExp(r'\p{L}', unicode: true);

bool _isRightToLeft(int rune) =>
    (rune >= 0x0590 && rune <= 0x08FF) ||
    (rune >= 0xFB1D && rune <= 0xFDFF) ||
    (rune >= 0xFE70 && rune <= 0xFEFF);

/// The direction [text] reads in, from its first letter, as a browser's
/// `dir="auto"` decides it; [fallback] when it has no letter at all.
TextDirection mtTextDirectionOf(String text, TextDirection fallback) {
  for (final rune in text.runes) {
    if (_isRightToLeft(rune)) return TextDirection.rtl;
    if (_letter.hasMatch(String.fromCharCode(rune))) return TextDirection.ltr;
  }
  return fallback;
}

/// A whole paragraph the app did not write (a title, a subtitle line),
/// laid out in its own direction but aligned with the interface.
///
/// [mtName] isolates a name inside a sentence; a paragraph that is nothing
/// but the name needs its own direction instead. Laid out in the
/// interface's, an English title under the Arabic interface moved its
/// closing "!" to the front and its ellipsis to the wrong end (seen on a
/// real phone). Aligning it with the interface keeps it in line with its
/// neighbours.
(TextDirection, TextAlign) mtForeignLine(BuildContext context, String text) {
  final ambient = Directionality.of(context);
  return (
    mtTextDirectionOf(text, ambient),
    ambient == TextDirection.rtl ? TextAlign.right : TextAlign.left,
  );
}
