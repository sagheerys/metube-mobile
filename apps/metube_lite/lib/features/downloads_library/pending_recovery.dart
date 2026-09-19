import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import '../home/network_gate.dart';
import 'download_wiring.dart';
import 'library_providers.dart';
import 'local_item.dart';

/// **Finishing, at launch, what the last run promised.**
///
/// Lite's whole promise is that the server cleans itself, and the engine
/// keeps it only while the process lives. The audit of 2026-09-19 found ten
/// ways for a file to be left behind, and three of them are this one: the
/// app stopped watching — killed from the recents list, stopped by the
/// battery manager, or failed by a single network blip — while the server
/// carried on and finished the file. Nobody was left to pull it or delete
/// the row.
///
/// The records the engine writes ([PendingDownloadsStore]) survive that,
/// and this hands them to [PendingSweeper] once, here, at startup.
///
/// **Silent by design.** Whoever opens the app is not shown a report about
/// a download they asked for yesterday: the file simply appears in the
/// library, the server is clean, and the diagnostic log says what happened.
///
/// A provider rather than a free function taking a `WidgetRef`: the sweep
/// outlives any frame, and a recovered file goes through the same
/// [onDownloadCompleted] as a live one, which wants a [Ref].
final pendingRecoveryProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => _recover(ref),
);

Future<void> _recover(Ref ref) async {
  final api = ref.read(apiClientProvider);
  if (api == null) return;
  final logger = ref.read(loggerProvider);
  final gate = ref.read(networkGateProvider);
  if (ref.read(settingsProvider).wifiOnly) {
    // The gate is pessimistic until the system's first answer, and that
    // answer usually lands a moment after this runs. Waiting for it turns
    // "deferred to the next launch" into "pulled now" — bounded, so a
    // plugin that never answers cannot hold the sweep forever.
    await gate.ready.timeout(const Duration(seconds: 3), onTimeout: () {});
  }
  final sweeper = PendingSweeper(
    api: api,
    store: ref.read(pendingDownloadsProvider),
    // Named like a live download: the same builder, the same title.
    savePathBuilder: (pending, item) =>
        '$liteMediaDir/${buildLocalFilename(item.title, serverFilename: item.filename)}',
    // The same gate the engine asks, for the same reason: a recovered pull
    // is still a pull, and "Wi-Fi only" means it.
    pullGate: () => !ref.read(settingsProvider).wifiOnly || gate.onWifi,
    // **The same road a live completion takes** — the offline index under
    // the canonical URL, the title, the cover, the gallery scan, the
    // backup — so a recovered file is not a nameless stranger in the
    // library.
    onFinished: (item, path, {required serverCleaned}) => onDownloadCompleted(
      ref,
      DownloadTask(
        inputUrl: item.canonicalUrl,
        quality: Quality.best,
        canonicalUrl: item.canonicalUrl,
        serverFilename: item.filename,
        title: item.title,
        thumbnail: item.thumbnail,
        localPath: path,
        phase: TaskPhase.completed,
        progress: 1,
        serverCleanupFailed: !serverCleaned,
      ),
    ),
    onLog: (message) => unawaited(logger.log(message, tag: 'pending')),
  );

  final outcomes = await sweeper.sweep();
  if (outcomes.values.contains(SweepOutcome.finished)) {
    // `onDownloadCompleted` already refreshed the library per file; this
    // covers the last one landing after its refresh.
    ref.invalidate(localMediaProvider);
  }
}
