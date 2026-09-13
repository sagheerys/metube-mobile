import 'dart:async';

import '../api/api_exceptions.dart';
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

  /// [checkAborted] throws on cancellation or engine disposal; [onProgress]
  /// broadcasts the server's progress. Returns the completed item or throws
  /// a classified error.
  Future<HistoryItem> pollUntilDone({
    required String url,
    required Set<String> before,
    required void Function() checkAborted,
    required void Function(double progress) onProgress,
  }) async {
    var failuresInARow = 0;
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

      for (final item in [...history.done, ...history.active]) {
        if (!UrlKit.urlsMatch(item.canonicalUrl, url)) continue;
        if (before.contains(HistoryMatcher.signature(item))) continue;
        if (item.hasError) {
          final detail = item.error ?? item.rawStatus;
          throw item.isPlatformBlocked
              ? PlatformBlockedException(detail)
              : ServerErrorException(detail);
        }
        // A missing filename means we wait. It is never invented from the
        // title (trap §6.3).
        if (item.isCompleted && item.filename != null) return item;
        if (item.progress != null) onProgress(item.progress!);
      }

      await _pause(attempt);
    }
    throw const PollTimeoutException();
  }

  /// The wait between turns, skipped after the last one.
  Future<void> _pause(int attempt) async {
    if (attempt < maxAttempts - 1) await Future<void>.delayed(pollInterval);
  }
}
