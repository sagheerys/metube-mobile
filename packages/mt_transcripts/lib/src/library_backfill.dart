import 'dart:convert';
import 'dart:io';

import 'package:mt_core/mt_core.dart';

import 'subtitle_parser.dart';
import 'subtitle_source.dart';
import 'transcript.dart';
import 'transcript_bundle.dart';

/// Transcripts for clips downloaded before transcripts were turned on,
/// gathered on a computer into one file that Super imports.
///
/// The MeTube server cannot fetch these: it keys its records by URL, so a
/// subtitles job for a clip already in the library replaces the clip's own
/// record and hides it. The server is only read, for its list of clips.
///
/// Every answer is kept in [work] as it arrives, so a run stopped by a
/// block or by hand resumes where it left off.
class LibraryBackfill {
  LibraryBackfill({
    required this.source,
    required this.work,
    required this.languages,
    this.translations = false,
    this.pause = const Duration(seconds: 10),
    void Function(String line)? log,
    Future<void> Function(Duration)? wait,
    DateTime Function()? clock,
  }) : _log = log ?? ((_) {}),
       _wait = wait ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  final SubtitleSource source;
  final Directory work;
  final List<String> languages;

  /// Machine translations are asked for too. YouTube refuses them far
  /// sooner than a video's own tracks, so they are opt-in.
  final bool translations;

  /// Between two videos, so a library of hundreds is not a burst.
  final Duration pause;

  final void Function(String line) _log;
  final Future<void> Function(Duration) _wait;
  final DateTime Function() _clock;

  static final _spoken = RegExp(r'^([a-zA-Z]+)(-[a-zA-Z]+)?-orig$');

  /// The finished YouTube clips in [history], one per video.
  static List<HistoryItem> candidates(HistoryResponse history) {
    final seen = <String>{};
    return [
      for (final item in history.done)
        if (!item.isCaptions)
          if (UrlKit.youtubeVideoId(item.canonicalUrl) case final id?)
            if (seen.add(id)) item,
    ];
  }

  /// For each language: written subtitles, else the words as spoken, else
  /// (when [translations]) a machine translation. None, when none is
  /// offered.
  static List<TrackChoice> pickTracks(
    OfferedTracks offered,
    Iterable<String> languages, {
    required bool translations,
  }) => [
    for (final language in languages) ?_pick(offered, language, translations),
  ];

  static TrackChoice? _pick(
    OfferedTracks offered,
    String language,
    bool translations,
  ) {
    if (offered.written.contains(language)) {
      return TrackChoice(language, language, TrackKind.written);
    }
    final regional = offered.written
        .where((t) => t.startsWith('$language-') && !t.endsWith('-orig'))
        .toList();
    if (regional.isNotEmpty) {
      return TrackChoice(language, (regional..sort()).first, TrackKind.written);
    }
    final spoken =
        offered.automatic
            .where((t) => _spoken.firstMatch(t)?.group(1) == language)
            .toList()
          ..sort();
    if (spoken.isNotEmpty) {
      return TrackChoice(language, spoken.first, TrackKind.spoken);
    }
    if (translations && offered.automatic.contains(language)) {
      return TrackChoice(language, language, TrackKind.translated);
    }
    return null;
  }

  Future<BackfillReport> run(List<HistoryItem> clips, {int? limit}) async {
    final report = BackfillReport();
    var translating = translations;
    var fetches = 0;
    await work.create(recursive: true);

    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final id = UrlKit.youtubeVideoId(clip.canonicalUrl)!;
      final label = '[${i + 1}/${clips.length}] ${clip.title ?? id}';
      if (await _file('$id.gone').exists()) {
        report.gone++;
        continue;
      }
      final wanted = [
        for (final language in languages)
          if (!await _settled(id, language, translating)) language,
      ];
      if (wanted.isEmpty) {
        report.alreadyDone++;
        continue;
      }
      if (limit != null && fetches >= limit) break;
      if (fetches++ > 0) await _wait(pause);

      final FetchedTracks fetched;
      late List<TrackChoice> choices;
      try {
        fetched = await source.fetch(clip.canonicalUrl, (offered) {
          return choices = pickTracks(
            offered,
            wanted,
            translations: translating,
          );
        });
      } on BackfillRateLimited catch (e) {
        _log('$label: stopped, too many requests ($e)');
        report.stoppedByRateLimit = true;
        break;
      } on VideoGone catch (e) {
        await _file('$id.gone').writeAsString('$e');
        _log('$label: gone');
        report.gone++;
        continue;
      } on FetchFailed catch (e) {
        _log('$label: failed, will retry next run ($e)');
        report.failed++;
        continue;
      }

      final outcome = <String>[];
      for (final language in wanted) {
        final choice = choices.where((c) => c.language == language).firstOrNull;
        final text = choice == null ? null : fetched.texts[choice.track];
        if (choice == null) {
          await _markNothing(id, language, translating);
          report.nothingOffered++;
          outcome.add('$language: none');
        } else if (text == null) {
          // Refused or lost on the way: no answer yet, so no mark.
          outcome.add('$language: not delivered');
        } else if (await _save(clip, language, text)) {
          report.saved++;
          outcome.add('$language: ${choice.kind.name}');
        } else {
          await _markNothing(id, language, translating);
          report.nothingOffered++;
          outcome.add('$language: empty');
        }
      }
      _log('$label: ${outcome.join(', ')}');

      if (fetched.translationsRefused && translating) {
        translating = false;
        report.translationsRefused = true;
        _log(
          'Translations refused as too many requests: the rest of this '
          "run takes each video's own tracks only.",
        );
      }
    }
    return report;
  }

  /// Every transcript gathered so far, in the format Super imports.
  Future<String> bundle() async {
    final transcripts = <Transcript>[];
    if (await work.exists()) {
      await for (final entry in work.list()) {
        if (entry is! File || !entry.path.endsWith('.json')) continue;
        if (Transcript.fromJson(await _readJson(entry)) case final t?) {
          transcripts.add(t);
        }
      }
    }
    transcripts.sort((a, b) => a.canonicalUrl.compareTo(b.canonicalUrl));
    return TranscriptBundle.encode(transcripts);
  }

  File _file(String name) => File('${work.path}${Platform.pathSeparator}$name');

  /// Answered already: a transcript, or nothing offered when last asked
  /// with at least what would be asked now.
  Future<bool> _settled(String id, String language, bool translating) async {
    if (await _file('$id.$language.json').exists()) return true;
    final none = _file('$id.$language.none');
    if (!await none.exists()) return false;
    return !translating || await none.readAsString() == _askedAll;
  }

  static const _askedAll = 'with translations';

  Future<void> _markNothing(String id, String language, bool translating) =>
      _file('$id.$language.none')
          .writeAsString(translating ? _askedAll : 'own tracks only');

  Future<bool> _save(HistoryItem clip, String language, String text) async {
    final segments = SubtitleParser.parse(text);
    if (segments.isEmpty) return false;
    final transcript = Transcript(
      canonicalUrl: clip.canonicalUrl,
      language: language,
      source: 'captions',
      fetchedAt: _clock().toUtc(),
      segments: segments,
    );
    final id = UrlKit.youtubeVideoId(clip.canonicalUrl)!;
    await _file('$id.$language.json')
        .writeAsString(jsonEncode(transcript.toJson()));
    return true;
  }

  static Future<Object?> _readJson(File file) async {
    try {
      return jsonDecode(await file.readAsString());
    } on FormatException {
      return null;
    }
  }
}
