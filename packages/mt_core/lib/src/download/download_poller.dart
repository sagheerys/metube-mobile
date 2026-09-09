import 'dart:async';

import '../api/api_exceptions.dart';
import '../api/metube_api.dart';
import '../models/history_item.dart';
import '../urls/url_kit.dart';
import 'history_matcher.dart';

/// Polls `/history` until **this** task's item completes (§2.3).
///
/// Split out of `download_engine.dart` for the size limit (rule 4), and it
/// is also where the decisive rule from defect ح-3 lives: **fingerprints
/// from before the add are ignored**, so an old item is never attributed
/// to this task, whether that is an earlier error poisoning a retry or a
/// file at an old quality declaring a higher-quality request successful.
class DownloadPoller {
  const DownloadPoller({
    required this.api,
    required this.pollInterval,
    required this.maxAttempts,
  });

  final MeTubeApi api;
  final Duration pollInterval;
  final int maxAttempts;

  /// [checkAborted] throws on cancellation or engine disposal; [onProgress]
  /// broadcasts the server's progress. Returns the completed item or throws
  /// a classified error.
  Future<HistoryItem> pollUntilDone({
    required String url,
    required Set<String> before,
    required void Function() checkAborted,
    required void Function(double progress) onProgress,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      checkAborted();
      final history = await api.fetchHistory();

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
        // title
        // (trap §6.3).
        if (item.isCompleted && item.filename != null) return item;
        if (item.progress != null) onProgress(item.progress!);
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(pollInterval);
      }
    }
    throw const PollTimeoutException();
  }
}
