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

/// م-9 + م-10: يراقب مهام المحرك فيقود الإشعارات ووضع الخلفية.
///
/// وضع الخلفية يُفعَّل **أثناء وجود مهام نشطة فقط** ويُطفأ بانتهائها —
/// خدمة أمامية دائمة تستنزف البطارية وتُغضب أندرويد.
final downloadWatcherProvider = Provider<void>((ref) {
  final notifications = ref.watch(notificationsProvider);
  final logger = ref.watch(loggerProvider);
  var backgroundOn = false;
  final notified = <String>{};

  MTLocalizations l10n() => lookupMTLocalizations(
      Locale(ref.read(settingsProvider).localeCode ?? 'ar'));

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
            notificationIcon:
                const AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
            enableWifiLock: true,
            // **لا** نطلب استثناء تحسين البطارية: حوار نظام مزعج لضيف
            // العائلة، والخدمة الأمامية وحدها تكفي لجلسة تحميل قصيرة.
            shouldRequestBatteryOptimizationsOff: false,
          ),
        );
        if (ready) await FlutterBackground.enableBackgroundExecution();
      } else if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (e) {
      // رفض الإذن أو جهاز لا يدعمه: التحميل يستمر ما دام التطبيق مفتوحاً.
      backgroundOn = false;
      await logger.error('background mode failed', cause: e, tag: 'download');
    }
  }

  Future<void> handle(List<DownloadTask> tasks) async {
    final texts = l10n();
    for (final task in tasks) {
      final id = idOf(task);
      switch (task.phase) {
        case TaskPhase.pulling:
          await notifications.showProgress(
            id,
            title: task.title ?? texts.downloadingTitle,
            channelName: texts.activeDownloads,
            percent: (task.progress * 100).round(),
          );
        case TaskPhase.completed:
          if (!notified.add(task.id)) break;
          await notifications.cancel(id);
          await notifications.showResult(
            id,
            title: texts.downloadCompleteTitle,
            body: task.title ?? task.effectiveUrl,
            channelName: texts.downloadComplete,
            // نقرة الإشعار تُبرز العنصر في المكتبة (§1 من مسار التطبيق).
            payload: task.canonicalUrl ?? task.localPath,
          );
        case TaskPhase.failed:
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
          await notifications.cancel(id);
        default:
          break;
      }
    }
    await syncBackground(tasks.any((t) => !t.isFinished));
  }

  ref.listen<AsyncValue<List<DownloadTask>>>(
    engineTasksProvider,
    (_, next) => unawaited(handle(next.value ?? const [])),
  );
});

/// تهيئة الإشعارات مرة واحدة + ربط نقرة الاكتمال بإبراز العنصر.
Future<void> initDownloadNotifications(WidgetRef ref) async {
  final notifications = ref.read(notificationsProvider);
  await notifications.init(
    onOpenItem: (key) =>
        ref.read(highlightedItemProvider.notifier).state = key,
  );
  await notifications.requestPermission();
}
