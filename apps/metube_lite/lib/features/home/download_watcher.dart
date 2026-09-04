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

  /// **بصمة آخر إشعار نُشر لكل مهمة** — مرشّح تكرار.
  ///
  /// بلاغ المالك 2026-09-04: «العدّاد في الإشعارات لا يتحرك مع أنه في
  /// التطبيق يتحرك». [handle] تمرّ على **كل** المهام في كل بثّة، فسبع
  /// مهام متوازية كانت تعني سبع منشورات لكل تغيّر في أيٍّ منها — آلاف
  /// النداءات على قناة المنصة في الدقيقة. أندرويد يخنق النشر المفرط من
  /// التطبيق الواحد فيتجمّد ما يراه المستخدم. هنا: لا يُنشر إلا ما
  /// تغيّر نصّه أو نسبته فعلاً.
  final lastShown = <int, String>{};

  /// **تسلسل النشر**: `unawaited` على استدعاءات متلاحقة كان يسمح
  /// لنداء قديم أن يصل بعد أحدث منه، فيعيد النسبة إلى الوراء.
  Future<void> chain = Future.value();

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

  /// ينشر شريط تقدّم **إن تغيّر** عمّا نُشر آخر مرة لهذه المهمة.
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
        // **بلاغ المالك 2026-09-02:** الإشعار كان يبدأ عند السحب فقط،
        // فمرحلة السيرفر كلها (وهي الأطول عادة) تمر بلا أي إشعار —
        // يبدو التطبيق ساكناً. الآن كل مرحلة تُعلن نفسها.
        case TaskPhase.queued:
          await showProgressIfChanged(
            id,
            title: task.title ?? texts.downloadingTitle,
            body: texts.queuedSection,
            channelName: texts.activeDownloads,
            // طور بلا نسبة معروفة ⇒ شريط غير محدد لا شريط صفري ساكن.
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
            body: texts
                .onServerProgress((task.progress * 100).toStringAsFixed(0)),
            channelName: texts.activeDownloads,
            percent: (task.progress * 100).round(),
          );
        // م-42: الملف جاهز والسحب موقوف بانتظار Wi‑Fi — الإشعار يقول
        // السبب صراحة، وإلا بدا التطبيق عالقاً بلا تفسير.
        case TaskPhase.waitingForNetwork:
          await showProgressIfChanged(
            id,
            title: task.title ?? texts.downloadingTitle,
            body: texts.waitingForWifi,
            channelName: texts.activeDownloads,
            percent: null,
          );
        // **النسبة في نص الإشعار أيضاً** (بلاغ المالك 2026-09-03: «العداد
        // لا يظهر عند السحب من السيرفر إلى الجهاز»). شريط الإشعار وحده
        // لا يُقرأ رقماً، ومرحلة السحب هي الأطول في Lite.
        case TaskPhase.pulling:
          await showProgressIfChanged(
            id,
            title: task.title ?? texts.downloadingTitle,
            body: texts.pullingToDeviceProgress(
                (task.progress * 100).toStringAsFixed(0)),
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
          // **لحظة الذروة**: العنصر يصل المكتبة بتوهجة واحدة تتلاشى —
          // الاكتمال أسعد لحظة في التطبيق وكان يمر بلا أي احتفاء.
          // نفس آلية إبراز نقرة الإشعار: مسار واحد لا اثنان.
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
            // نقرة الإشعار تُبرز العنصر في المكتبة (§1 من مسار التطبيق).
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

  ref.listen<AsyncValue<List<DownloadTask>>>(
    engineTasksProvider,
    (_, next) {
      final tasks = next.value ?? const <DownloadTask>[];
      chain = chain.then((_) => handle(tasks)).catchError((Object e) {
        unawaited(logger.error('notification failed',
            cause: e, tag: 'download'));
      });
    },
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
