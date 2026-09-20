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

/// **Isolation for a name the app did not write** \u2014 a channel, an uploader,
/// a playlist, a tag, a title.
///
/// [mtLtrRun] forces left to right, which is right for a clock or a
/// fraction and wrong here: the name decides its own direction. `\u2068`
/// (FSI) takes the direction from the **first strong character in the name
/// itself**, so an Arabic channel reads right to left and an English one
/// left to right, whichever language the interface is in.
///
/// Field report 2026-09-20: an Arabic channel beside an English "5 minutes
/// ago" came apart \u2014 the separator and the neutral characters between the
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

/// A "a \u00b7 b \u00b7 c" line whose parts are each isolated, for the meta line
/// under a title. Empty parts are dropped rather than leaving a stray
/// separator.
String mtMetaLine(List<String?> parts) => [
  for (final part in parts)
    if (part != null && part.isNotEmpty) mtName(part),
].join(' \u00b7 ');
