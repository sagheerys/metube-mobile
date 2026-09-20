import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../home/download_watcher.dart' show notificationsProvider;
import 'subscriptions_providers.dart';

/// The watermark: the newest `/history` timestamp this app has already
/// accounted for, in milliseconds.
const arrivalWatermarkKey = 'subs_seen_timestamp';

/// A fixed id, so a second batch replaces the first notice instead of
/// stacking a second one beside it.
const arrivalNotificationId = 770001;

/// **Telling the user when the server brought something by itself**
/// (م-72).
///
/// Every other notification in this app is about a download **this app**
/// started, and comes from the engine. A subscription download has no task
/// here at all: MeTube decides, fetches, and the clip simply turns up in
/// `/history`. Without this, files appear on the server's disk and in the
/// library with nothing ever saying so.
///
/// **What counts as an arrival**: a completed item newer than the
/// watermark that this app did not submit. Anything the engine handled is
/// excluded, because the engine already announced it and a second notice
/// for the same file is worse than none.
///
/// **It cannot wake the app up.** There is no periodic background task
/// here, by choice: the check runs whenever `/history` is read — opening
/// the app, returning to it, pulling to refresh, or the live poll during a
/// download. So the notice arrives with the user, not before them. Adding
/// a real background poll is a separate decision with a battery cost.
class ArrivalWatcher {
  ArrivalWatcher(this._ref);

  final Ref _ref;

  /// Canonical URLs this app asked for during this run. The engine
  /// announces these itself.
  final Set<String> _mine = {};

  /// Null until the stored watermark has been read once.
  int? _watermark;
  bool _loaded = false;
  bool _busy = false;

  void noteOwnTask(String? canonicalUrl) {
    if (canonicalUrl != null && canonicalUrl.isNotEmpty) {
      _mine.add(canonicalUrl);
    }
  }

  Future<void> onHistory(HistoryResponse history) async {
    // One pass at a time: `/history` can be re-read every two seconds
    // during a download, and two passes would both read the old watermark
    // and notify twice for the same clips.
    if (_busy) return;
    _busy = true;
    try {
      await _process(history);
    } on Object {
      // A notice nobody can post is not worth breaking the library over.
    } finally {
      _busy = false;
    }
  }

  Future<void> _process(HistoryResponse history) async {
    final done = history.done.where((item) => item.isCompleted).toList();
    if (done.isEmpty) return;

    final store = _ref.read(keyValueStoreProvider);
    if (!_loaded) {
      _watermark = await store.getInt(arrivalWatermarkKey);
      _loaded = true;
    }

    var newest = _watermark ?? 0;
    for (final item in done) {
      final at = item.timestamp?.millisecondsSinceEpoch;
      if (at != null && at > newest) newest = at;
    }

    // **The first run announces nothing.** A fresh install, or a phone
    // restored from a backup, would otherwise report the server's entire
    // library as having just arrived.
    if (_watermark == null) {
      await _save(store, newest);
      return;
    }

    final arrivals = [
      for (final item in done)
        if ((item.timestamp?.millisecondsSinceEpoch ?? 0) > _watermark! &&
            !_mine.contains(item.canonicalUrl))
          item,
    ];

    // The watermark moves whether or not anyone is told, so a batch is
    // never reported twice.
    await _save(store, newest);
    if (arrivals.isEmpty) return;
    if (!_ref.read(settingsProvider).notifyArrivals) return;

    // **Only when a subscription could explain it.** Someone who queued a
    // clip from MeTube's own web page should not be told their phone
    // downloaded something; with no subscriptions at all, this app has no
    // business claiming to know where the file came from.
    final subs = _ref.read(subscriptionsProvider).valueOrNull;
    if (subs == null || !subs.sorted.any((sub) => sub.enabled)) return;

    await _announce(arrivals);
  }

  Future<void> _save(KeyValueStore store, int value) async {
    _watermark = value;
    await _ref
        .read(prefsMutexProvider)
        .run(() => store.setInt(arrivalWatermarkKey, value));
  }

  Future<void> _announce(List<HistoryItem> arrivals) async {
    final l10n = lookupMTLocalizations(
      Locale(_ref.read(settingsProvider).localeCode ?? 'ar'),
    );
    // **One notice for the batch**, as asked 2026-09-20: a channel checked
    // hourly can deliver several clips at once, and one line per clip
    // would be the reason the feature gets turned off.
    // A server record can carry no title at all; its URL is the only thing
    // it is guaranteed to have, and an empty notification body says less
    // than an ugly one.
    String nameOf(HistoryItem item) => (item.title?.trim().isNotEmpty ?? false)
        ? item.title!.trim()
        : item.canonicalUrl;
    final body = arrivals.length == 1
        ? nameOf(arrivals.first)
        : arrivals.take(3).map(nameOf).join(' · ');
    await _ref
        .read(notificationsProvider)
        .showResult(
          arrivalNotificationId,
          title: l10n.newFromSubscriptions(arrivals.length),
          body: body,
          channelName: l10n.subscriptions,
          // Tapping opens the app on the newest of them.
          payload: arrivals.first.canonicalUrl,
        );
    await _ref
        .read(loggerProvider)
        .log('subscription arrivals: ${arrivals.length}', tag: 'subs');
  }
}

/// The watcher itself, separate from the wiring below so a test can drive
/// it a history at a time instead of simulating the whole app.
final arrivalWatcherInstanceProvider = Provider<ArrivalWatcher>(
  ArrivalWatcher.new,
);

/// Kept alive from the shell, like the download watcher.
final arrivalWatcherProvider = Provider<void>((ref) {
  final watcher = ref.watch(arrivalWatcherInstanceProvider);

  // Everything the engine touches is ours, whatever state it is in.
  ref.listen<AsyncValue<List<DownloadTask>>>(engineTasksProvider, (_, next) {
    for (final task in next.valueOrNull ?? const <DownloadTask>[]) {
      watcher.noteOwnTask(task.canonicalUrl);
    }
  }, fireImmediately: true);

  ref.listen<AsyncValue<HistoryResponse?>>(historyProvider, (_, next) {
    final history = next.valueOrNull;
    if (history != null) unawaited(watcher.onHistory(history));
  }, fireImmediately: true);
});
