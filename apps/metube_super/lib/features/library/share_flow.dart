import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart' show mtLocalizationsFor;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../di.dart';
import '../home/download_watcher.dart' show notificationsProvider;
import '../shared/error_report.dart';
import 'device_pulls.dart';
import 'library_actions.dart';
import 'share_job.dart';

export 'share_job.dart';

/// The notice that a copy finished, or failed, while the app was away.
const shareNotificationId = 770002;

/// A clip this large asks before it downloads: on mobile data one stray
/// tap would otherwise cost the whole file.
const shareConfirmBytes = 500 * 1024 * 1024;

final shareSendProvider = Provider<Future<void> Function(String path)>(
  (ref) =>
      (path) async => Share.shareXFiles([XFile(path)]),
);

/// Waits until what was just set is on screen, but never for long: a
/// frame that does not come (no window, a test) must not hold the share.
final shareFrameProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => WidgetsBinding.instance.endOfFrame.timeout(
        const Duration(milliseconds: 250),
        onTimeout: () {},
      ),
);

/// A folder of its own, so a sweep never touches anything else in the
/// cache. A provider because `path_provider` does not work in tests.
final shareDirProvider = FutureProvider<String>(
  (ref) async => '${(await getTemporaryDirectory()).path}/share',
);

/// Is the app on screen? The share menu cannot open from the background.
final shareForegroundProvider = Provider<bool Function()>(
  (ref) =>
      () => switch (WidgetsBinding.instance.lifecycleState) {
        null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
        _ => false,
      },
);

final shareFlowProvider = NotifierProvider<ShareFlow, ShareJob?>(ShareFlow.new);

/// Pulls a clip that is only on the server, then opens the share menu.
class ShareFlow extends Notifier<ShareJob?> {
  /// Bumped by every start and cancel, so a copy that ends after its share
  /// was cancelled shares nothing.
  int _run = 0;
  AppLifecycleListener? _life;
  String? _ready;
  bool _noticed = false;

  /// Set by the sheet while it is open. A failure nobody can see is told
  /// by a notice instead, and the share is cleared for the next try.
  bool watched = false;

  @override
  ShareJob? build() {
    ref.onDispose(() => _life?.dispose());
    return null;
  }

  /// One share at a time: a second call while one runs does nothing, so a
  /// double tap pulls the clip once.
  Future<void> start(LibraryItem item) async {
    if (state != null) return;
    final filename = item.serverFilename;
    if (filename == null) throw const UnsafeFilenameException();
    final url = item.canonicalUrl;
    final run = ++_run;
    // A clip already being saved to the phone is shared from that copy
    // rather than downloaded a second time.
    final saving = ref.read(libraryActionsProvider).runningOffline(url);
    state = ShareJob(
      url: url,
      title: item.title,
      kind: saving == null ? PullKind.share : PullKind.offline,
    );
    try {
      final path = saving == null
          ? await _copy(item, filename, run)
          : await saving;
      // Cancelled while the copy ran: nothing is shared.
      if (path == null || run != _run || state == null) return;
      await _deliver(path);
    } on CancelledException {
      if (run == _run) _finish();
    } on Object catch (e) {
      if (run != _run || state == null) return;
      unawaited(logError(ref.read(loggerProvider), e, tag: 'share'));
      if (watched && ref.read(shareForegroundProvider)()) {
        state = state!.copyWith(phase: SharePhase.failed, error: e);
      } else {
        await _notice(e);
        state = null;
      }
    }
  }

  /// The share's own copy, in a folder of its own. Null when the share was
  /// cancelled before the copy began.
  Future<String?> _copy(LibraryItem item, String filename, int run) async {
    final url = item.canonicalUrl;
    final dir = await ref.read(shareDirProvider.future);
    await Directory(dir).create(recursive: true);
    await sweepShareFolder(dir);
    await ensureRoom(ref, dir, item.sizeBytes);
    if (run != _run) return null;
    final pulls = ref.read(devicePullsProvider.notifier);
    final cancel = pulls.begin(
      PullKind.share,
      url,
      item.title,
      total: item.sizeBytes,
    );
    if (cancel == null) return null;
    try {
      // The pull may pick another name if this one is taken, so what is
      // shared is the path it returns.
      return await ref.read(phonePullProvider)(
        serverFilename: filename,
        savePath:
            '$dir/${buildLocalFilename(item.title, serverFilename: filename)}',
        cancel: cancel,
        onBytes: (received, total) =>
            pulls.report(PullKind.share, url, received, total),
      );
    } finally {
      // Ended before the share menu: it is awaited until it closes, and the
      // card read 100% all that time.
      pulls.end(PullKind.share, url);
    }
  }

  Future<void> _deliver(String path) async {
    if (ref.read(shareForegroundProvider)()) {
      await _handOver(path);
      return;
    }
    // Away from the app: wait for the user to come back, and say so.
    _ready = path;
    state = state!.copyWith(phase: SharePhase.ready);
    _life = AppLifecycleListener(onResume: () => unawaited(sendReady()));
    await _notice(null);
  }

  /// Opens the share menu for a copy that finished while the app was away.
  Future<void> sendReady() async {
    final path = _ready;
    if (path == null) return;
    _stopWaiting();
    await _handOver(path);
  }

  /// The share menu opens only once Android's share plugin has copied the
  /// file, seconds for a large clip, during which the app stands still. The
  /// sheet says so first, and goes as soon as the menu covers the app.
  Future<void> _handOver(String path) async {
    final job = state;
    if (job == null) return;
    state = job.copyWith(phase: SharePhase.opening);
    await ref.read(shareFrameProvider)();
    void done() {
      if (state?.phase == SharePhase.opening) _finish();
    }

    final life = AppLifecycleListener(onInactive: done, onHide: done);
    try {
      await ref.read(shareSendProvider)(path);
    } finally {
      life.dispose();
      done();
    }
  }

  /// Stops the share. Its own copy stops with it; an offline copy it was
  /// waiting on goes on, being something the user asked for separately.
  void cancel() {
    final job = state;
    if (job == null) return;
    if (job.kind == PullKind.share) {
      ref.read(devicePullsProvider.notifier).cancel(PullKind.share, job.url);
    }
    _run++;
    _finish();
  }

  /// Closes a failed share once its message has been read.
  void dismiss() => _finish();

  /// The sheet went away. A failure it showed is done with; any other phase
  /// goes on without it. Later, because the sheet is still being torn down.
  void sheetClosed() {
    watched = false;
    if (state?.phase == SharePhase.failed) unawaited(Future.microtask(_finish));
  }

  Future<void> _notice(Object? error) async {
    final job = state;
    if (job == null) return;
    final l10n = mtLocalizationsFor(ref.read(settingsProvider).localeCode);
    _noticed = true;
    await ref
        .read(notificationsProvider)
        .showResult(
          shareNotificationId,
          title: error == null ? l10n.shareReady : l10n.failed,
          body: job.title,
          channelName: l10n.activeDownloads,
          payload: job.url,
          isError: error != null,
        );
  }

  void _finish() {
    _stopWaiting();
    state = null;
  }

  void _stopWaiting() {
    _ready = null;
    _life?.dispose();
    _life = null;
    if (_noticed) {
      _noticed = false;
      unawaited(ref.read(notificationsProvider).cancel(shareNotificationId));
    }
  }
}
