import 'dart:async';
import 'dart:io';

import '../api/api_exceptions.dart';
import '../api/metube_api.dart';
import '../models/history_item.dart';
import '../models/history_response.dart';
import '../urls/url_kit.dart';
import 'history_matcher.dart';
import 'pending_downloads.dart';
import 'transfer.dart';

/// What became of one record.
enum SweepOutcome {
  /// Pulled to the device and cleaned off the server: the promise kept.
  finished,

  /// The file was already on the phone — the process died, or the server
  /// refused, during the delete — so only the server needed cleaning.
  cleaned,

  /// The server is still working on it. The record stays for next time.
  stillRunning,

  /// The server failed it. The leftover row is removed and so is the
  /// record.
  failed,

  /// Nothing on the server matches it any more — already cleaned, or by
  /// another device. The record goes.
  gone,

  /// The file exists but this app cannot pull it — a name the path guard
  /// refuses, or a 404 for the file itself. Retrying at every launch would
  /// change nothing, so the record goes; the row is left for the web UI.
  unrecoverable,

  /// The gate said not now (Wi-Fi only, no Wi-Fi). Nothing is touched.
  deferred,
}

/// Called for every file the sweep **pulled**, with the item as the server
/// described it and where the file landed. [serverCleaned] is false when
/// the delete that followed was refused, so the caller does not read a
/// file that is still there as a misconfigured server.
typedef SweepFinished = Future<void> Function(
  HistoryItem item,
  String localPath, {
  required bool serverCleaned,
});

/// **Finishing what the app started before it was killed.**
///
/// Lite's promise is that the server cleans itself, and the engine keeps
/// that promise only while the process lives. It dies often and for
/// ordinary reasons — the recents list, the battery manager, a restart —
/// and the server carries on and finishes the file regardless. Every one of
/// those leaves a file nobody pulls and a row nobody deletes.
///
/// **Deliberately outside [DownloadEngine].** The engine is the most
/// dangerous file in the project and it works; this needs none of its queue,
/// its concurrency or its parking. It reads a record, looks the item up in
/// `/history`, and reuses the same two pieces the engine uses for the last
/// two stages — [Transfer] and `delete`. If it were folded into the engine
/// it would have to re-enter a state machine halfway, which is exactly the
/// kind of surgery that breaks working code.
class PendingSweeper {
  PendingSweeper({
    required this.api,
    required this.store,
    required this.savePathBuilder,
    this.pullGate,
    this.onFinished,
    this.onLog,
    Transfer? transfer,
  }) : _transfer = transfer ?? Transfer(api: api);

  final MeTubeApi api;
  final PendingDownloadsStore store;

  /// Where the pulled file goes, given the record and the item as the
  /// server describes it — the app's decision, as in the engine, and with
  /// the same title, so a recovered file is named like any other.
  final String Function(PendingDownload pending, HistoryItem item)
  savePathBuilder;

  /// "Wi-Fi only", asked **before each pull**. A closed gate defers the
  /// record rather than dropping it: the file is not going anywhere.
  final bool Function()? pullGate;

  /// What the app does after a live download completes — indexing,
  /// artwork, the gallery — done here too, so a recovered file is not a
  /// second-class item.
  final SweepFinished? onFinished;

  final void Function(String message)? onLog;

  final Transfer _transfer;

  /// Sweeps every record. Returns what happened to each, for the tests and
  /// for the log.
  ///
  /// **Never throws.** It runs at startup, before anything is on screen,
  /// and a failure here must not become a failure to launch. One unreachable
  /// server simply means "not this time".
  Future<Map<String, SweepOutcome>> sweep() async {
    final records = await store.readAll();
    if (records.isEmpty) return const {};
    final HistoryResponse history;
    try {
      history = await api.fetchHistory();
    } on Object catch (e) {
      onLog?.call('pending sweep skipped: $e');
      return const {};
    }
    final outcomes = <String, SweepOutcome>{};
    // One `/history` serves the whole sweep, so a row one record has taken
    // must not be handed to the next: two records for the same link would
    // both pull it, and the second would find nothing left to pull.
    final claimed = <String>{};
    for (final pending in records) {
      try {
        outcomes[pending.id] = await _sweepOne(pending, history, claimed);
      } on Object catch (e) {
        // One bad record must not stop the rest.
        onLog?.call('pending sweep failed for ${pending.id}: $e');
        outcomes[pending.id] = SweepOutcome.stillRunning;
      }
    }
    final done = outcomes.values.where(
      (o) => o == SweepOutcome.finished || o == SweepOutcome.cleaned,
    );
    onLog?.call(
      'pending sweep: ${records.length} record(s), ${done.length} finished',
    );
    return outcomes;
  }

  Future<SweepOutcome> _sweepOne(
    PendingDownload pending,
    HistoryResponse history,
    Set<String> claimed,
  ) async {
    final item = _ours(pending, history, claimed);
    if (item == null) {
      await store.remove(pending.id);
      return SweepOutcome.gone;
    }
    claimed.add(HistoryMatcher.signature(item));
    if (item.hasError) {
      // The server kept the row, and a leftover error row poisons the next
      // retry of the same link (that is why the engine snapshots at all).
      await _deleteQuietly(item.canonicalUrl);
      await store.remove(pending.id);
      return SweepOutcome.failed;
    }
    if (!item.isCompleted || item.filename == null) {
      return SweepOutcome.stillRunning;
    }
    final onPhone = pending.localPath;
    if (onPhone != null && File(onPhone).existsSync()) {
      // The pull already happened; only the delete did not.
      if (!await _deleteQuietly(item.canonicalUrl)) {
        return SweepOutcome.stillRunning;
      }
      await store.remove(pending.id);
      return SweepOutcome.cleaned;
    }
    if (!(pullGate?.call() ?? true)) return SweepOutcome.deferred;

    final String path;
    try {
      path = await _transfer.pull(
        serverFilename: item.filename!,
        savePath: savePathBuilder(pending, item),
      );
    } on UnsafeFilenameException catch (e) {
      return _giveUp(pending, e);
    } on NoApiException catch (e) {
      return _giveUp(pending, e);
    }
    onLog?.call('pending sweep pulled ${item.filename} to $path');
    // **Only after the file is safely on the device.** A delete that ran
    // first would destroy the one copy if the pull then failed.
    final cleaned = await _deleteQuietly(item.canonicalUrl);
    await onFinished?.call(item, path, serverCleaned: cleaned);
    if (!cleaned) {
      // The file is on the phone; say so, and let the next launch retry
      // the delete alone.
      await store.put(pending.copyWith(localPath: path));
      return SweepOutcome.finished;
    }
    await store.remove(pending.id);
    return SweepOutcome.finished;
  }

  Future<SweepOutcome> _giveUp(PendingDownload pending, Object cause) async {
    onLog?.call('pending sweep cannot pull ${pending.id}: $cause');
    await store.remove(pending.id);
    return SweepOutcome.unrecoverable;
  }

  /// The item this record is about: matching the URL, absent from the
  /// pre-add fingerprints — so an older row for the same link, a previous
  /// failure or another quality, is never adopted — and not yet taken by
  /// an earlier record in this sweep.
  HistoryItem? _ours(
    PendingDownload pending,
    HistoryResponse history,
    Set<String> claimed,
  ) {
    for (final item in [...history.done, ...history.active]) {
      if (!UrlKit.urlsMatch(item.canonicalUrl, pending.url)) continue;
      final signature = HistoryMatcher.signature(item);
      if (pending.before.contains(signature)) continue;
      if (claimed.contains(signature)) continue;
      return item;
    }
    return null;
  }

  /// Cleaning the server is best effort: the file is already on the phone,
  /// and failing here must not lose the record's completion. Returns
  /// whether the server accepted the delete.
  Future<bool> _deleteQuietly(String canonicalUrl) async {
    try {
      await api.delete([canonicalUrl]);
      return true;
    } on MTApiException catch (e) {
      onLog?.call('pending sweep could not clean the server: $e');
      return false;
    }
  }
}
