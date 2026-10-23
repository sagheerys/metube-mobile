import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';

/// The downloads the server stopped with an error, whoever added them: this
/// phone in an earlier session, a subscription, MeTube's own page or
/// another device. The engine only knows what this phone added since it
/// started, so these were otherwise visible on the server's page alone.
///
/// Only rows the server marks as failed. A finished row is a library item
/// and never appears here. A row this phone is already showing as its own
/// failed task is left out, so one failure is not listed twice.
final serverFailuresProvider = Provider<List<HistoryItem>>((ref) {
  final history = ref.watch(historyProvider).valueOrNull;
  if (history == null) return const [];
  final tasks = ref.watch(engineTasksProvider).valueOrNull ?? const [];
  final shownHere = {
    for (final task in tasks)
      if (task.phase == TaskPhase.failed)
        ...[task.canonicalUrl, task.resolvedUrl, task.inputUrl].nonNulls,
  };
  return [
    for (final item in history.done)
      if (item.status == ItemStatus.failed &&
          !shownHere.contains(item.canonicalUrl))
        item,
  ];
});

final serverFailureActionsProvider = Provider(ServerFailureActions.new);

/// Retrying and removing failed rows on the server.
///
/// **Both ask the server again first and act only on rows still failed.**
/// MeTube keeps one row per link, and the sheet may be minutes old: a link
/// retried from MeTube's page since then may have finished, and removing
/// it by link would remove the finished download, file and all.
class ServerFailureActions {
  ServerFailureActions(this._ref);

  final Ref _ref;

  /// Removes the failed rows for [urls] from the server's list, and returns
  /// how many were still failed and so removed.
  Future<int> remove(Iterable<String> urls) async {
    final api = _ref.read(apiClientProvider);
    if (api == null) return 0;
    final failed = await _stillFailed(api, urls);
    if (failed.isNotEmpty) await api.delete(failed);
    _ref.invalidate(historyProvider);
    return failed.length;
  }

  /// Sends [items] again with the quality, format and folder they were
  /// added with, and returns how many were sent.
  Future<int> retry(List<HistoryItem> items) async {
    final api = _ref.read(apiClientProvider);
    final engine = _ref.read(downloadEngineProvider);
    if (api == null || engine == null) return 0;
    final failed = (await _stillFailed(api, [
      for (final item in items) item.canonicalUrl,
    ])).toSet();
    final again = [
      for (final item in items)
        if (failed.contains(item.canonicalUrl)) item,
    ];
    if (again.isEmpty) return 0;
    // **Removed before it is added, never after.** The new attempt takes
    // the same row when it finishes; a removal sent after the add could
    // land on the finished row and delete its file.
    await api.delete([for (final item in again) item.canonicalUrl]);
    for (final item in again) {
      engine.submit(
        item.canonicalUrl,
        retryQuality(item),
        isBatchMember: again.length > 1,
        folder: item.folder,
      );
    }
    _ref.invalidate(historyProvider);
    return again.length;
  }

  Future<List<String>> _stillFailed(
    MeTubeApiClient api,
    Iterable<String> urls,
  ) async {
    final history = await api.fetchHistory();
    final failed = {
      for (final item in history.done)
        if (item.status == ItemStatus.failed) item.canonicalUrl,
    };
    return [
      for (final url in urls.toSet())
        if (failed.contains(url)) url,
    ];
  }
}

/// The quality a failed row is retried with: audio stays audio, and a
/// numeric quality is kept for YouTube only, as when it was first added.
Quality retryQuality(HistoryItem item) => item.downloadType == 'audio'
    ? Quality.audio
    : Quality.fromWire(item.quality).applyRule(item.canonicalUrl);

/// The server's reason in one readable line. yt-dlp writes several lines
/// behind an `ERROR:` and an `[extractor]` tag, then often the video id
/// ("[youtube] abc: Video unavailable"); on a phone only the first sentence
/// says anything.
String? failureReason(HistoryItem item) {
  final raw = item.error?.trim();
  if (raw == null || raw.isEmpty) return null;
  final first = raw
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty);
  final reason = first
      .replaceFirst(RegExp(r'^ERROR:\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^\[[^\]]+\]\s*([\w-]+:\s+)?'), '')
      .trim();
  return reason.isEmpty ? first : reason;
}
