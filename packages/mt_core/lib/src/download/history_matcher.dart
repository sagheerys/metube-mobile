import '../api/metube_api.dart';
import '../models/history_item.dart';
import '../urls/url_kit.dart';

/// The history reconciler: it ties a task to **its own** operation on the
/// server, and sweeps what cancelled tasks leave behind.
///
/// **Why it exists:** polling used to match any item in
/// `/history` by URL alone, so it picked up **old** items. An item that had
/// previously failed at a cookie wall made a retry fail instantly while the
/// new download completed and was orphaned on the server; an item at an old
/// 480 quality declared a 1080 request successful and the wrong file was
/// pulled. The fix is **a snapshot taken before the add**: every item is
/// ignored, with its fingerprint as it was at add time, until that
/// fingerprint changes through a new completion or a new error.
class HistoryMatcher {
  const HistoryMatcher(this.api);

  final MeTubeApi api;

  /// An item's fingerprint: URL, file, status, error. Any real progress by
  /// the new operation changes it, and an old item sitting unchanged does
  /// not.
  static String signature(HistoryItem item) =>
      '${item.canonicalUrl}|${item.filename}|${item.status.name}|${item.error}';

  /// Fingerprints of everything matching [url] in the history **before**
  /// the add. A failed fetch returns an empty set, since the add that
  /// follows will reveal the network outage by itself.
  Future<Set<String>> snapshot(String url) async {
    try {
      final history = await api.fetchHistory();
      return {
        for (final item in [...history.done, ...history.active])
          if (UrlKit.urlsMatch(item.canonicalUrl, url)) signature(item),
      };
    } on Object {
      return const <String>{};
    }
  }

  /// Sweeps the server orphan left by a user cancellation.
  ///
  /// Cancelling during the add or the poll used to stop the task **locally
  /// only**: the server carried on downloading and filed the result in
  /// `done`, with no path in the app to remove it, and the orphan poisoned
  /// later retries. Here only what appeared **after** the snapshot is
  /// deleted, so an item that existed before this task is never touched.
  Future<void> deleteOrphan(String url, Set<String> before) async {
    try {
      final history = await api.fetchHistory();
      for (final item in history.active) {
        if (!UrlKit.urlsMatch(item.canonicalUrl, url)) continue;
        if (before.contains(signature(item))) continue;
        await api.delete([item.canonicalUrl], where: 'queue');
        return;
      }
      for (final item in history.done) {
        if (!UrlKit.urlsMatch(item.canonicalUrl, url)) continue;
        if (before.contains(signature(item))) continue;
        await api.delete([item.canonicalUrl]);
        return;
      }
    } on Object {
      // A best-effort sweep: its failure means nothing to a user who has
      // already cancelled.
    }
  }
}
