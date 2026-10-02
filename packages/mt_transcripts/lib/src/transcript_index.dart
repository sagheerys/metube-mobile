import 'search_text.dart';
import 'transcript.dart';

/// How closely a moment matched, best first.
enum MatchKind {
  /// The words as typed, in that order: said exactly.
  phrase,

  /// Every word, in any order, in one caption.
  sameLine,

  /// Every word within [TranscriptIndex.nearby] of each other: said in the
  /// same breath, even if the captions split it.
  nearby,
}

/// Where a query was said in one clip.
class TranscriptHit {
  const TranscriptHit({
    required this.start,
    required this.text,
    required this.language,
    required this.kind,
    this.next,
  });

  /// The second to open the player at.
  final Duration start;

  /// The line as the subtitles wrote it, for display.
  final String text;

  /// The line after it, so a result can be judged without opening it.
  final String? next;
  final String language;
  final MatchKind kind;
}

/// Every place a query was found in one clip.
class ClipHits {
  const ClipHits({
    required this.canonicalUrl,
    required this.hits,
    required this.total,
  });

  final String canonicalUrl;

  /// The best moments, in the order they were said.
  final List<TranscriptHit> hits;

  /// Every moment found, of which [hits] is the best few.
  final int total;

  MatchKind get best =>
      hits.map((h) => h.kind).reduce((a, b) => a.index <= b.index ? a : b);
}

/// The search over every stored transcript, held in memory.
///
/// It is **derived, never the record**: built from the transcript files and
/// thrown away with the app, so changing how text is folded needs no
/// migration — the next launch folds it the new way.
///
/// A clip may hold one transcript per language; they are searched apart
/// (a word from each language never makes a match together) and their
/// moments are listed together.
class TranscriptIndex {
  final Map<String, Map<String, _Entry>> _clips = {};

  /// Words this far apart still count as said together.
  static const nearby = Duration(seconds: 30);

  /// Shorter than this, a query matches nearly every clip and says
  /// nothing.
  static const minQueryLength = 2;

  /// How many clips hold at least one transcript.
  int get length => _clips.length;

  void add(Transcript transcript) {
    final url = transcript.canonicalUrl;
    if (transcript.isEmpty) {
      _clips[url]?.remove(transcript.language);
      if (_clips[url]?.isEmpty ?? false) _clips.remove(url);
      return;
    }
    (_clips[url] ??= {})[transcript.language] = _Entry(transcript, [
      for (final s in transcript.segments) SearchText.fold(s.text),
    ]);
  }

  void remove(String canonicalUrl) => _clips.remove(canonicalUrl);

  void clear() => _clips.clear();

  bool contains(String canonicalUrl) => _clips.containsKey(canonicalUrl);

  /// Every language kept for a clip, for reading it whole.
  List<Transcript> transcriptsFor(String canonicalUrl) => [
    for (final entry in (_clips[canonicalUrl] ?? const {}).values)
      entry.transcript,
  ];

  /// Clips in which [query] was said: the closest match first, then the
  /// most matches. At most [perClip] moments are kept for each, the
  /// closest matches first, so one long talk cannot bury every other clip.
  List<ClipHits> search(String query, {int perClip = 5}) {
    final phrase = SearchText.fold(query);
    if (phrase.length < minQueryLength) return const [];
    final words = SearchText.wordsOf(query);

    final results = <ClipHits>[];
    for (final MapEntry(key: url, value: languages) in _clips.entries) {
      final found = <TranscriptHit>[
        for (final entry in languages.values) ..._hitsIn(entry, phrase, words),
      ];
      if (found.isEmpty) continue;
      final unique = _dropEchoes(found);
      final shown = ([...unique]..sort(_closestFirst)).take(perClip).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      results.add(
        ClipHits(canonicalUrl: url, hits: shown, total: unique.length),
      );
    }
    results.sort((a, b) {
      final kind = a.best.index.compareTo(b.best.index);
      return kind != 0 ? kind : b.total.compareTo(a.total);
    });
    return results;
  }

  static List<TranscriptHit> _hitsIn(
    _Entry entry,
    String phrase,
    List<String> words,
  ) {
    final segments = entry.transcript.segments;
    final folded = entry.folded;
    final hits = <TranscriptHit>[];
    TranscriptHit hit(int i, MatchKind kind) => TranscriptHit(
      start: segments[i].start,
      text: segments[i].text,
      next: i + 1 < segments.length ? segments[i + 1].text : null,
      language: entry.transcript.language,
      kind: kind,
    );

    var i = 0;
    while (i < folded.length) {
      if (_phraseAt(folded, i, phrase)) {
        hits.add(hit(i, MatchKind.phrase));
        i++;
        continue;
      }
      if (words.length > 1 && words.every(folded[i].contains)) {
        hits.add(hit(i, MatchKind.sameLine));
        i++;
        continue;
      }
      if (words.length > 1 && words.any(folded[i].contains)) {
        final end = _windowEnd(segments, i);
        final window = folded.sublist(i, end).join(' ');
        if (words.every(window.contains)) {
          hits.add(hit(i, MatchKind.nearby));
          // The window is one moment: starting another inside it would
          // list the same sentence several times.
          i = end;
          continue;
        }
      }
      i++;
    }
    return hits;
  }

  /// Found in this line, or begun here and finished on the next: a caption
  /// ends wherever the screen ran out of width, not where a phrase does.
  /// The second case is counted at the line where the phrase starts, and
  /// only when neither line holds it alone, so a match is never counted
  /// twice.
  static bool _phraseAt(List<String> folded, int i, String phrase) {
    final line = folded[i];
    if (line.contains(phrase)) return true;
    if (i + 1 >= folded.length) return false;
    final next = folded[i + 1];
    if (next.contains(phrase)) return false;
    return '$line $next'.contains(phrase);
  }

  /// The first line past [nearby] from line [i].
  static int _windowEnd(List<TranscriptSegment> segments, int i) {
    final limit = segments[i].start + nearby;
    var end = i + 1;
    while (end < segments.length && segments[end].start <= limit) {
      end++;
    }
    return end;
  }

  /// A translated track shares its timings with the original, so a word
  /// found in both at the same second is one moment, kept at its closest
  /// match.
  static List<TranscriptHit> _dropEchoes(List<TranscriptHit> hits) {
    final byClosest = [...hits]..sort(_closestFirst);
    final kept = <TranscriptHit>[];
    for (final hit in byClosest) {
      final echo = kept.any(
        (k) => (k.start - hit.start).abs() < const Duration(seconds: 1),
      );
      if (!echo) kept.add(hit);
    }
    return kept;
  }

  static int _closestFirst(TranscriptHit a, TranscriptHit b) {
    final kind = a.kind.index.compareTo(b.kind.index);
    return kind != 0 ? kind : a.start.compareTo(b.start);
  }
}

class _Entry {
  const _Entry(this.transcript, this.folded);

  final Transcript transcript;
  final List<String> folded;
}
