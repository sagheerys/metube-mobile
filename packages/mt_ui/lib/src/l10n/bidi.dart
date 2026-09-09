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
