import 'package:mt_core/mt_core.dart';

import 'subtitle_parser.dart';
import 'transcript.dart';

/// How a fetch ended.
enum CaptionsOutcome {
  /// A transcript came back and is in [CaptionsResult.transcript].
  fetched,

  /// The clip has no subtitles in that language, or none at all.
  none,

  /// Refused before asking: the clip is already on the server (see
  /// [CaptionsFetcher]).
  alreadyOnServer,

  /// Only YouTube links are fetched for now (see [CaptionsFetcher]).
  unsupported,

  /// The server failed, or did not finish in time.
  failed,
}

class CaptionsResult {
  const CaptionsResult(this.outcome, {this.transcript, this.detail});

  final CaptionsOutcome outcome;
  final Transcript? transcript;

  /// Why it failed, for the diagnostic log.
  final String? detail;
}

/// Fetches a clip's subtitles through MeTube **without disturbing the
/// library**, before the clip itself is downloaded.
///
/// MeTube keys finished jobs by URL alone, so a subtitles job for a clip
/// already in the history replaces that clip's entry: it vanishes from the
/// library and its file is orphaned (measured, SERVER-API.md §2.2). Three
/// rules follow, and each has a test that fails without it:
///
/// 1. **Nothing is asked for a clip the server already knows**, in any
///    list. Checked immediately before asking.
/// 2. **Only YouTube links**, because rule 1 needs the canonical form of
///    the URL before the server has seen it, and only YouTube's is
///    knowable in advance (from the video id). Another site may rewrite the
///    URL, and the check would compare the wrong strings.
/// 3. **Only a subtitles entry is ever deleted.** The cleanup reads the
///    entry's type first, so a video that arrived under the same URL in the
///    meantime is left alone.
///
/// The subtitles entry and its file are deleted once read, so nothing is
/// left on the server and the video can be added right after.
class CaptionsFetcher {
  CaptionsFetcher(
    this.api, {
    this.pollInterval = const Duration(seconds: 2),
    this.timeout = const Duration(seconds: 60),
    Future<void> Function(Duration)? wait,
    DateTime Function()? clock,
  }) : _wait = wait ?? Future<void>.delayed,
       _clock = clock ?? DateTime.now;

  final MeTubeApi api;
  final Duration pollInterval;

  /// A subtitles job took 20 seconds on a real server; three times that
  /// is a server in trouble, and the video should not wait longer.
  final Duration timeout;
  final Future<void> Function(Duration) _wait;
  final DateTime Function() _clock;

  Future<CaptionsResult> fetch(String url, {required String language}) async {
    final id = UrlKit.youtubeVideoId(url);
    if (id == null) return const CaptionsResult(CaptionsOutcome.unsupported);

    if (_find(await api.fetchHistory(), id) != null) {
      return const CaptionsResult(CaptionsOutcome.alreadyOnServer);
    }
    await api.addCaptions(
      'https://www.youtube.com/watch?v=$id',
      language: language,
    );

    // **Time, not a count of readings.** Each reading can itself take many
    // seconds on a slow link, and the video waits behind this job.
    final deadline = _clock().add(timeout);
    final polls = timeout.inMilliseconds ~/ pollInterval.inMilliseconds;
    HistoryItem? running;
    for (var i = 0; i < polls && _clock().isBefore(deadline); i++) {
      await _wait(pollInterval);
      final HistoryResponse history;
      try {
        history = await api.fetchHistory();
      } on MTApiException {
        // One missed reading is not a failure: the job is still running
        // on the server, and giving up here would leave it to finish later
        // on top of the video.
        continue;
      }
      final finished = _findIn(history.done, id);
      if (finished != null) return _collect(finished, language);
      running = _findIn([...history.queue, ...history.pending], id) ?? running;
    }
    // One last look before giving up: if every reading failed, the job is
    // still unknown here, and left running it would land on the video.
    try {
      final last = await api.fetchHistory();
      final finished = _findIn(last.done, id);
      if (finished != null) return await _collect(finished, language);
      running = _findIn([...last.queue, ...last.pending], id) ?? running;
    } on MTApiException {
      // Cancel with what is known.
    }
    await _cancel(running);
    return const CaptionsResult(CaptionsOutcome.failed, detail: 'timed out');
  }

  /// Reads the finished entry, then deletes it whatever happened.
  Future<CaptionsResult> _collect(HistoryItem entry, String language) async {
    if (!entry.isCaptions) {
      // Someone added the video itself meanwhile: not ours to touch.
      return const CaptionsResult(
        CaptionsOutcome.failed,
        detail: 'the clip itself arrived first',
      );
    }
    try {
      final filename = entry.filename;
      if (entry.hasError) {
        return CaptionsResult(CaptionsOutcome.failed, detail: entry.error);
      }
      if (filename == null) {
        return const CaptionsResult(CaptionsOutcome.none);
      }
      final segments = SubtitleParser.parse(await api.fetchText(filename));
      if (segments.isEmpty) return const CaptionsResult(CaptionsOutcome.none);
      return CaptionsResult(
        CaptionsOutcome.fetched,
        transcript: Transcript(
          canonicalUrl: entry.canonicalUrl,
          // What was asked for, not the track's own label (`en-orig`,
          // say): a clip holds one transcript per language asked.
          language: language,
          source: 'captions',
          fetchedAt: DateTime.now(),
          segments: segments,
        ),
      );
    } on MTApiException catch (e) {
      return CaptionsResult(CaptionsOutcome.failed, detail: '$e');
    } finally {
      await _deleteCaptions(entry, where: 'done');
    }
  }

  /// A job still running when time ran out is cancelled, so it cannot
  /// finish later and take the video's place.
  Future<void> _cancel(HistoryItem? entry) async {
    if (entry == null) return;
    await _deleteCaptions(entry, where: 'queue');
  }

  Future<void> _deleteCaptions(
    HistoryItem entry, {
    required String where,
  }) async {
    if (!entry.isCaptions) return; // rule 3
    try {
      await api.delete([entry.canonicalUrl], where: where);
    } on MTApiException {
      // Left for the server's owner to clear; the caller still gets its answer.
    }
  }

  /// The entry for this video in any list, by its id: the server may have
  /// written the URL in another form than the one that was sent.
  static HistoryItem? _find(HistoryResponse history, String id) =>
      _findIn([...history.queue, ...history.pending, ...history.done], id);

  static HistoryItem? _findIn(List<HistoryItem> items, String id) {
    for (final item in items) {
      if (UrlKit.youtubeVideoId(item.canonicalUrl) == id) return item;
    }
    return null;
  }
}
