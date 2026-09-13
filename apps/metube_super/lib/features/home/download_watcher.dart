import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/library_providers.dart';
import '../shared/error_text.dart';
import 'notifications.dart';

final notificationsProvider = Provider((ref) => DownloadNotifications());

/// **Download notifications in Super** (decision 2026-09-06).
///
/// Super had no notification at all, neither completion nor failure:
/// anyone who left the app after adding a link learned what happened only
/// by coming back. And an error review (2026-09-06) showed failure was
/// worse off: a "needs your attention" card is seen only by someone who
/// opens the management sheet.
///
/// **A foreground service while, and only while, a download is active**
/// (field report 2026-09-13). Super used to have none, on the reasoning that
/// its files stay on the server so nothing has to survive in the background.
/// Measured on the emulator: seconds after the user left the app Android
/// froze it, not one `/history` request went out for 90 seconds, and the
/// progress notification sat at 5% until the app was opened again. The
/// service is Lite's own, started with the first active task and stopped
/// with the last, so an idle Super holds nothing.
final downloadWatcherProvider = Provider<void>((ref) {
  final notifications = ref.watch(notificationsProvider);
  final logger = ref.watch(loggerProvider);
  final notified = <String>{};
  var backgroundOn = false;

  /// The last notification's fingerprint per task. Without this filter,
  /// seven tasks are posted on every broadcast, thousands of calls a
  /// minute, so Android throttles them and what the user sees freezes.
  final lastShown = <int, String>{};

  /// Posting sequence: an older call used to arrive after a newer one and
  /// put the percentage back.
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
            // No battery-optimisation exemption: an intrusive system dialog,
            // and the foreground service alone carries a download session.
            shouldRequestBatteryOptimizationsOff: false,
          ),
        );
        if (ready) await FlutterBackground.enableBackgroundExecution();
      } else if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (e) {
      // A refused permission or an unsupported device: the download still
      // runs while the app is open, as it did before.
      backgroundOn = false;
      await logger.error('background mode failed', cause: e, tag: 'download');
    }
  }

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
      final title = task.title ?? texts.downloadingTitle;
      switch (task.phase) {
        case TaskPhase.queued:
          await showProgressIfChanged(
            id,
            title: title,
            body: texts.queuedSection,
            channelName: texts.activeDownloads,
            percent: null,
          );
        case TaskPhase.adding:
          await showProgressIfChanged(
            id,
            title: title,
            body: texts.addingToServer,
            channelName: texts.activeDownloads,
            percent: null,
          );
        case TaskPhase.polling:
          await showProgressIfChanged(
            id,
            title: title,
            body: texts.onServerProgress(
              (task.progress * 100).toStringAsFixed(0),
            ),
            channelName: texts.activeDownloads,
            percent: (task.progress * 100).round(),
          );
        case TaskPhase.waitingForNetwork:
          await showProgressIfChanged(
            id,
            title: title,
            body: texts.waitingForWifi,
            channelName: texts.activeDownloads,
            percent: null,
          );
        // Pulling is the exception in Super ("available offline" and
        // batches), but it is the longest phase when it happens, so the
        // percentage goes in the text and not in the bar alone.
        case TaskPhase.pulling:
          await showProgressIfChanged(
            id,
            title: title,
            body: texts.pullingToDeviceProgress(
              (task.progress * 100).toStringAsFixed(0),
            ),
            channelName: texts.activeDownloads,
            percent: (task.progress * 100).round(),
          );
        case TaskPhase.deleting:
          await showProgressIfChanged(
            id,
            title: title,
            body: texts.cleaningServer,
            channelName: texts.activeDownloads,
            percent: null,
          );
        case TaskPhase.completed:
          lastShown.remove(id);
          if (!notified.add(task.id)) break;
          await notifications.cancel(id);
          await notifications.showResult(
            id,
            title: texts.downloadCompleteTitle,
            body: task.title ?? task.effectiveUrl,
            channelName: texts.downloadComplete,
            // The tap highlights the item in the library, the same path as
            // the completion highlight.
            payload: task.canonicalUrl ?? task.localPath,
          );
        case TaskPhase.failed:
          lastShown.remove(id);
          if (!notified.add(task.id)) break;
          await notifications.cancel(id);
          await notifications.showResult(
            id,
            title: texts.downloadFailedTitle,
            // **The failure reason in the notification itself**: "failed"
            // alone leaves the user guessing between a dropped network, a
            // refused link and wrong credentials.
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

/// Called once at startup from the shell.
///
/// **It never lets a fault escape into the startup chain**: the platform
/// call throws in an environment with no channel (widget tests, desktop)
/// and even on devices that do not register the plugin, and the `initState`
/// chain after it carries share reception and the shortcuts, so its failure
/// disables things with nothing to do with notifications.
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
