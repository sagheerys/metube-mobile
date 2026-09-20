import '../api/metube_api.dart';
import '../models/history_item.dart';
import '../models/history_response.dart';
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

  /// The history, or null when it could not be read. **Null is not "the
  /// server is empty"**: read as empty, every item on the server would look
  /// new a moment later.
  Future<HistoryResponse?> read() async {
    try {
      return await api.fetchHistory();
    } on Object {
      return null;
    }
  }

  /// Fingerprints of everything matching [url] in the history **before**
  /// the add. A failed fetch returns an empty set, since the add that
  /// follows will reveal the network outage by itself.
  Future<Set<String>> snapshot(String url) async =>
      signaturesFor(await read(), url);

  static Set<String> signaturesFor(HistoryResponse? history, String url) => {
    if (history != null)
      for (final item in [...history.done, ...history.active])
        if (UrlKit.urlsMatch(item.canonicalUrl, url)) signature(item),
  };

  /// **Every item on the server as key → fingerprint.**
  ///
  /// The key is the URL MeTube filed the item under, which is the identity
  /// the server itself answers to: `PersistentQueue` is keyed by it, and
  /// `/delete` and `/start` take it in their `ids`. It is **not** always the
  /// URL we sent — when extraction ends somewhere else, the server files
  /// what yt-dlp ended at (`docs/SERVER-API.md` §2.3), and every defect of
  /// the "downloads on the server, hangs in the app" family is that gap.
  static Map<String, String> fingerprints(HistoryResponse history) => {
    for (final item in [...history.done, ...history.active])
      item.canonicalUrl: signature(item),
  };

  /// The **one** key that appeared or changed between two readings, or null
  /// when none did or more than one did.
  ///
  /// Straight after our own `/add`, one change means one thing: the server
  /// acted on what we asked for, under whatever key it chose. That key is
  /// then an exact identity, and the URL guessing in [UrlKit.urlsMatch] is
  /// not needed at all.
  ///
  /// **More than one change gives up on purpose.** On a shared server
  /// somebody else may add or finish something in the same seconds, and a
  /// wrong adoption in Lite means pulling a stranger's file and deleting it
  /// from the server — the 2026-09-02 defect, re-entered by a new door.
  /// Ambiguity falls back to the URL match, which is where we were.
  ///
  /// A **re-add of something already there** changes its status rather than
  /// adding a key, which is why a changed fingerprint counts as much as a
  /// new one: without that, our own duplicate would be invisible here while
  /// somebody else's new download would be the only change — and we would
  /// adopt theirs.
  static String? soleChange(
    Map<String, String> before,
    Map<String, String> now,
  ) {
    String? only;
    for (final entry in now.entries) {
      if (before[entry.key] == entry.value) continue;
      if (only != null) return null;
      only = entry.key;
    }
    return only;
  }

  /// Removes the item filed under [key], wherever it sits.
  ///
  /// The key **is** the id MeTube's lists are indexed by, so this cannot
  /// hit a neighbour. Which list it is in still has to be read, because
  /// `where` is not optional and a wrong one is a silent no-op. Best
  /// effort, like [deleteOrphan]: a cancellation that cannot reach the
  /// server is still a cancellation.
  Future<void> deleteByKey(String key) async {
    try {
      final history = await api.fetchHistory();
      if (history.active.any((item) => item.canonicalUrl == key)) {
        await api.delete([key], where: 'queue');
      } else if (history.done.any((item) => item.canonicalUrl == key)) {
        await api.delete([key]);
      }
    } on Object {
      // Nothing to tell a user who has already walked away.
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
