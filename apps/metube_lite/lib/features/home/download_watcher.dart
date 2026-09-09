import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../downloads_library/library_providers.dart';
import '../shared/error_text.dart';
import 'notifications.dart';

final notificationsProvider = Provider((ref) => DownloadNotifications());

/// Watches the engine's tasks and drives the notifications and the
/// background mode.
///
/// Background mode is enabled **only while tasks are active** and switched
/// off when they end: a permanent foreground service drains the battery and
/// angers Android.
final downloadWatcherProvider = Provider<void>((ref) {
  final notifications = ref.watch(notificationsProvider);
  final logger = ref.watch(loggerProvider);
  var backgroundOn = false;
  final notified = <String>{};

  /// **The fingerprint of the last notification posted per task**: a
  /// duplicate filter.
  ///
  /// Field report 2026-09-04: "the counter in the notifications does not
  /// move even though it moves in the app". [handle] walks **every** task
  /// on every broadcast, so seven parallel tasks meant seven posts for
  /// every change in any one of them, thousands of calls a minute on the
  /// platform channel. Android throttles excessive posting from a single
  /// app and what the user sees freezes. Here, nothing is posted unless its
  /// text or its percentage actually changed.
  final lastShown = <int, String>{};

  /// **Posting sequence**: `unawaited` on consecutive calls let an older
  /// one arrive after a newer one and put the percentage back.
  Future<void> chain = Future.value();

  MTLocalizations l10n() => lookupMTLocalizations(
    Locale(ref.read(settingsProvider).localeCode ?? 'ar'),
  );

  int idOf(DownloadTask task) => task.id.hashCode & 0x7fffffff;

  Future<void> syncBackground(bool anyActive) async {
    if (anyActive == backgroundOn) return;
    backgroundOn = anyActive;
    try {
      if (anyActive) {
        final texts = l10n();
        final ready = await FlutterBackground.initialize(
          androidConfig: FlutterBackgroundAndroidConfig(
            notificationTitle: texts.downloadingTitle,
            notificationText: texts.backgroundDownload,
            notificationImportance: AndroidNotificationImportance.normal,
            notificationIcon: const AndroidResource(
              name: 'ic_launcher',
              defType: 'mipmap',
            ),
            enableWifiLock: true,
            // We do **not** request a battery-optimisation exemption: it is
            // an intrusive system dialog for a family member, and the
            // foreground service alone is enough for a short download
            // session.
            shouldRequestBatteryOptimizationsOff: false,
          ),
        );
        if (ready) await FlutterBackground.enableBackgroundExecution();
      } else if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (e) {
      // A refused permission or a device that does not support it:
      // downloading continues as long as the app is open.
      backgroundOn = false;
      await logger.error('background mode failed', cause: e, tag: 'download');
    }
  }

  /// Posts a progress bar **if it changed** from what was last posted for
  /// this task.
  Future<void> showProgressIfChanged(
    int id, {
    required String title,
    required String channelName,
    required int? percent,
    required String body,
  }) async {
    final signature = '$title|$body|${percent ?? -1}';
    if (lastShown[id] == signature) return;
    lastShown[id] = signature;
    await notifications.showProgress(
      id,
      title: title,
      body: body,
      channelName: channelName,
      percent: percent,
    );
  }

  Future<void> handle(List<DownloadTask> tasks) async {
    final texts = l10n();
    for (final task in tasks) {
      final id = idOf(task);
      switch (task.phase) {
        // **Field report 2026-09-02:** the notification used to start at
        // the pull only, so the entire server phase, usually the longest,
        // passed with no notification at all and the app looked idle. Now
        // every phase announces itself.
        case TaskPhase.queued:
          await showProgressIfChanged(
            id,
            title: task.title ?? texts.downloadingTitle,
            body: texts.queuedSection,
            channelName: texts.activeDownloads,
            // A phase with no known percentage gets an indeterminate bar
            // rather than a bar frozen at zero.
            percent: null,
          );
        case TaskPhase.adding:
          await showProgressIfChanged(
            id,
            title: task.title ?? texts.downloadingTitle,
            body: texts.addingToServer,
            channelName: texts.activeDownloads,
            percent: null,
          );
        case TaskPhase.polling:
          await showProgressIfChanged(
            id,
            title: task.title ?? texts.downloadingTitle,
            body: texts.onServerProgress(
              (task.progress * 100).toStringAsFixed(0),
            ),
            channelName: texts.activeDownloads,
            percent: (task.progress * 100).round(),
          );
        // The file is ready and the pull is held waiting for Wi-Fi; the
        // notification says so plainly, or the app looks stuck with no
        // explanation.
        case TaskPhase.waitingForNetwork:
          await showProgressIfChanged(
            id,
            title: task.title ?? texts.downloadingTitle,
            body: texts.waitingForWifi,
            channelName: texts.activeDownloads,
            percent: null,
          );
        // **The percentage in the notification text too** (field report
        // 2026-09-03: "the counter does not appear while pulling from the
        // server to the device"). A notification bar on its own cannot be
        // read as a number, and pulling is the longest phase in Lite.
        case TaskPhase.pulling:
          await showProgressIfChanged(
            id,
            title: task.title ?? texts.downloadingTitle,
            body: texts.pullingToDeviceProgress(
              (task.progress * 100).toStringAsFixed(0),
            ),
            channelName: texts.activeDownloads,
            percent: (task.progress * 100).round(),
          );
        case TaskPhase.deleting:
          await showProgressIfChanged(
            id,
            title: task.title ?? texts.downloadingTitle,
            body: texts.cleaningServer,
            channelName: texts.activeDownloads,
            percent: null,
          );
        case TaskPhase.completed:
          lastShown.remove(id);
          if (!notified.add(task.id)) break;
          // **The peak moment**: the item arrives in the library with one
          // highlight that fades. Completion is the happiest moment in the
          // app and it used to pass with no celebration at all. It uses the
          // same mechanism as the notification-tap highlight: one path, not
          // two.
          final arrived = task.canonicalUrl ?? task.localPath;
          if (arrived != null) {
            ref.read(highlightedItemProvider.notifier).state = arrived;
          }
          await notifications.cancel(id);
          await notifications.showResult(
            id,
            title: texts.downloadCompleteTitle,
            body: task.title ?? task.effectiveUrl,
            channelName: texts.downloadComplete,
            // A notification tap highlights the item in the library (§1 of
            // the app flow).
            payload: task.canonicalUrl ?? task.localPath,
          );
        case TaskPhase.failed:
          lastShown.remove(id);
          if (!notified.add(task.id)) break;
          await notifications.cancel(id);
          await notifications.showResult(
            id,
            title: texts.downloadFailedTitle,
            body: task.error == null
                ? texts.failed
                : errorText(texts, task.error!),
            channelName: texts.downloadFailed,
            isError: true,
          );
        case TaskPhase.cancelled:
          lastShown.remove(id);
          await notifications.cancel(id);
      }
    }
    await syncBackground(tasks.any((t) => !t.isFinished));
  }

  ref.listen<AsyncValue<List<DownloadTask>>>(engineTasksProvider, (_, next) {
    final tasks = next.valueOrNull ?? const <DownloadTask>[];
    chain = chain.then((_) => handle(tasks)).catchError((Object e) {
      unawaited(logger.error('notification failed', cause: e, tag: 'download'));
    });
  });
});

/// Initialises the notifications once and wires the completion tap to the
/// item highlight.
/// **It never lets a fault escape into the startup chain** (the same cure
/// as Super): the platform call throws in an environment with no channel,
/// and what follows it in `initState` has nothing to do with notifications.
Future<void> initDownloadNotifications(WidgetRef ref) async {
  final notifications = ref.read(notificationsProvider);
  try {
    await notifications.init(
      onOpenItem: (key) =>
          ref.read(highlightedItemProvider.notifier).state = key,
    );
    await notifications.requestPermission();
  } on Object catch (e) {
    // The logging itself is defensive: the logger may not be injected in a
    // test environment.
    try {
      unawaited(
        ref
            .read(loggerProvider)
            .error('notifications init failed', cause: e, tag: 'download'),
      );
    } on Object {
      // An environment with no logger: only the notifications are missing
      // and downloading works.
    }
  }
}
