import 'dart:async';

import '../api/api_exceptions.dart';
import '../api/live_update.dart';
import '../api/metube_api.dart';
import '../models/history_item.dart';
import '../models/history_response.dart';
import '../urls/url_kit.dart';
import 'history_matcher.dart';

/// Polls `/history` until **this** task's item completes (§2.3).
///
/// Split out of `download_engine.dart` for the size limit (rule 4), and it
/// is also where the decisive rule lives: **fingerprints
/// from before the add are ignored**, so an old item is never attributed
/// to this task, whether that is an earlier error poisoning a retry or a
/// file at an old quality declaring a higher-quality request successful.
class DownloadPoller {
  const DownloadPoller({
    required this.api,
    required this.pollInterval,
    required this.maxAttempts,
    this.networkTolerance = 0,
  });

  final MeTubeApi api;
  final Duration pollInterval;
  final int maxAttempts;

  /// **How many `/history` requests in a row may fail on the network before
  /// the task fails** (field report 2026-09-13, Super). Leaving the app
  /// mid-download let Android freeze it or cut its network; the first
  /// request afterwards failed, the task was reported failed, and the server
  /// finished the file anyway. 0 keeps "the first network error fails",
  /// which is Lite's rule. A tolerated failure still spends an attempt, so
  /// [maxAttempts] stays the ceiling, and cancellation is still checked on
  /// every turn.
  final int networkTolerance;

  /// **How many turns may be spent identifying the item by key** before the
  /// task settles for URL matching.
  ///
  /// `/add` returns once the server has filed the item, so one turn is
  /// normally enough; a couple more cover a slow filesystem. It is bounded
  /// because the comparison is against a reading from **before** the add,
  /// and the longer that window is left open the more of somebody else's
  /// activity falls inside it — which does not adopt the wrong item, it
  /// just gives up more often.
  static const int identifyTurns = 3;

  /// [checkAborted] throws on cancellation or engine disposal; [onProgress]
  /// broadcasts the server's progress. Returns the completed item or throws
  /// a classified error.
  ///
  /// [fingerprintsBefore] is the whole server as it was before the add
  /// (`HistoryMatcher.fingerprints`). Given it, the poller identifies **the
  /// one thing that changed** and follows that key exactly, which is the
  /// only way to follow an item the server filed under a URL we never sent.
  /// Without it, or when the change is ambiguous, matching is by URL
  /// exactly as before. [onIdentified] reports the key the moment it is
  /// known, so the task can be deleted, cancelled and recorded by it.
  Future<HistoryItem> pollUntilDone({
    required String url,
    required Set<String> before,
    required void Function() checkAborted,
    required void Function(double progress) onProgress,
    Map<String, String>? fingerprintsBefore,
    void Function(String key)? onIdentified,
    Stream<MTLiveUpdate>? live,
  }) async {
    var failuresInARow = 0;
    String? key;
    // **Progress only moves forward, and stops short of the end until the
    // server says done.** yt-dlp counts each stream of a clip from zero
    // (the video, then the audio), so the raw figure would run to 100 and
    // back.
    var shown = 0.0;
    void progress(double value) {
      final next = value.clamp(0.0, 0.99);
      if (next <= shown) return;
      shown = next;
      onProgress(next);
    }

    // Between two reads the live channel reports progress as it happens,
    // and the server's "done" cuts the wait short. Completion itself is
    // still read from `/history`, which names the finished file.
    var wake = Completer<void>();
    final updates = live?.listen((update) {
      final item = update.item;
      if (item.isCaptions) return;
      final ours = key != null
          ? item.canonicalUrl == key
          : UrlKit.urlsMatch(item.canonicalUrl, url);
      if (!ours) return;
      if (update.completed || item.hasError) {
        if (!wake.isCompleted) wake.complete();
      } else if (_streamProgress(item) case final value?) {
        progress(value);
      }
    });
    try {
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        checkAborted();
        final HistoryResponse history;
        try {
          history = await api.fetchHistory();
          failuresInARow = 0;
        } on NetworkException {
          if (++failuresInARow > networkTolerance) rethrow;
          await _pause(attempt);
          continue;
        }

        if (key == null &&
            fingerprintsBefore != null &&
            attempt < identifyTurns) {
          key = HistoryMatcher.soleChange(
            fingerprintsBefore,
            HistoryMatcher.fingerprints(history),
          );
          if (key != null) onIdentified?.call(key);
        }

        final finished = history.done.toSet();
        for (final item in [...history.done, ...history.active]) {
          // A subtitles job shares its clip's URL but its file is a
          // transcript: taken for the download, it would be pulled as the
          // clip, and in Lite deleted from the server as one.
          if (item.isCaptions) continue;
          if (key != null) {
            if (item.canonicalUrl != key) continue;
          } else if (!UrlKit.urlsMatch(item.canonicalUrl, url)) {
            continue;
          }
          // **The fingerprint rule survives the key, and must.** `done` and
          // `queue` are separate lists, so one URL can be an old failure in
          // one and this attempt in the other; the key picks the URL, and
          // only this keeps the old failure from failing the new request —
          // the 2026-09-01 defect, which has a guard of its own. It can never
          // skip our own item: what we adopted, we adopted **because** its
          // fingerprint was not there before.
          if (before.contains(HistoryMatcher.signature(item))) continue;
          if (item.hasError) {
            final detail = item.error ?? item.rawStatus;
            throw item.isPlatformBlocked
                ? PlatformBlockedException(detail)
                : ServerErrorException(detail);
          }
          // A missing filename means we wait. It is never invented from the
          // title (trap §6.3). **Only the done list is done** (field report
          // 2026-10-15): yt-dlp fetches a clip's subtitles, video and audio
          // one by one, and each reads "finished" in the queue with its own
          // file, which is deleted once they are merged. Taken for the clip,
          // the app stopped following it early, and Lite went to pull a
          // file that was about to vanish.
          if (item.isCompleted &&
              item.filename != null &&
              finished.contains(item)) {
            return item;
          }
          if (_streamProgress(item) case final value?) progress(value);
        }

        await _pause(attempt, wake.future);
        wake = Completer<void>();
      }
      throw const PollTimeoutException();
    } finally {
      await updates?.cancel();
    }
  }

  /// The share of the clip's own media downloaded, or null when the
  /// reading says nothing about it: a subtitles file, a stream that is not
  /// downloading, or the 100% a finished stream leaves behind until the
  /// next one reports.
  static double? _streamProgress(HistoryItem item) {
    final value = item.progress;
    if (value == null || value >= 1 || item.rawStatus != 'downloading') {
      return null;
    }
    final file = (item.filename ?? '').toLowerCase();
    const subtitles = ['.vtt', '.srt', '.ass', '.lrc', '.ttml', '.json3'];
    if (subtitles.any(file.endsWith)) return null;
    return value;
  }

  /// The wait between turns, skipped after the last one, and cut short
  /// when [early] completes.
  Future<void> _pause(int attempt, [Future<void>? early]) async {
    if (attempt >= maxAttempts - 1) return;
    await Future.any([Future<void>.delayed(pollInterval), ?early]);
  }
}
