/// One timed line of speech.
class TranscriptSegment {
  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;

  Map<String, Object> toJson() => {
    's': start.inMilliseconds,
    'e': end.inMilliseconds,
    't': text,
  };

  static TranscriptSegment? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final s = raw['s'], e = raw['e'], t = raw['t'];
    if (s is! int || e is! int || t is! String) return null;
    return TranscriptSegment(
      start: Duration(milliseconds: s),
      end: Duration(milliseconds: e),
      text: t,
    );
  }
}

/// A clip's transcript, as stored on the phone.
///
/// It is written once and never edited: fetching it again yields a new one
/// that replaces the file. So two devices can never disagree about one
/// transcript, only hold two equally valid ones, which is what makes
/// carrying them between devices a plain copy.
class Transcript {
  const Transcript({
    required this.canonicalUrl,
    required this.language,
    required this.source,
    required this.fetchedAt,
    required this.segments,
  });

  /// The format written by this code. A reader meeting a higher number
  /// skips the file rather than misreading it.
  static const schema = 1;

  /// The key of every piece of app data, as `/history` reports it.
  final String canonicalUrl;

  /// The language that was asked for, such as `ar` or `en`.
  final String language;

  /// Where the text came from, such as `captions`: a later source (speech
  /// recognition) must be told apart from subtitles.
  final String source;
  final DateTime fetchedAt;
  final List<TranscriptSegment> segments;

  bool get isEmpty => segments.isEmpty;

  Map<String, Object> toJson() => {
    'schema': schema,
    'url': canonicalUrl,
    'lang': language,
    'source': source,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'segments': [for (final s in segments) s.toJson()],
  };

  /// The language alone, as the app asks for it: `ar` from `ar-orig` or
  /// `ar-SA`. The first version of this code named a transcript after its
  /// subtitle file, `ar-orig` among them, which then showed as a language
  /// of its own beside `ar`.
  static String baseLanguage(String code) =>
      code.split('-').first.toLowerCase();

  /// Null for anything that is not a transcript this code can read.
  static Transcript? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['schema'];
    if (version is! int || version > schema) return null;
    final url = raw['url'], lang = raw['lang'], source = raw['source'];
    final fetched = DateTime.tryParse('${raw['fetchedAt']}');
    final list = raw['segments'];
    if (url is! String || lang is! String || source is! String) return null;
    if (fetched == null || list is! List) return null;
    return Transcript(
      canonicalUrl: url,
      language: baseLanguage(lang),
      source: source,
      fetchedAt: fetched,
      segments: [for (final s in list) ?TranscriptSegment.fromJson(s)],
    );
  }
}
