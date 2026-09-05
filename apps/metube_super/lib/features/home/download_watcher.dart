import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/library_providers.dart';
import '../shared/error_text.dart';
import 'notifications.dart';

final notificationsProvider = Provider((ref) => DownloadNotifications());

/// **إشعارات التحميل في Super (قرار المالك 2026-09-06).**
///
/// كان Super بلا إشعار البتة — لا اكتمال ولا فشل: من يغادر التطبيق بعد
/// إضافة رابط لا يعرف ما جرى إلا بعودته. وفحص الأخطاء (2026-09-06) بيّن
/// أن الفشل كان أسوأ حالاً: بطاقة «تحتاج انتباهك» لا يراها إلا من فتح
/// ورقة الإدارة.
///
/// **ولا خدمة أمامية هنا خلافاً لـ Lite:** Lite يسحب كل ملف إلى الجهاز
/// فيحتاج بقاءً في الخلفية، أما Super فيُبقي على السيرفر (§4) — والسحب
/// استثناء («إتاحة دون اتصال» والدفعي). خدمة دائمة لأجل الاستثناء
/// تستنزف البطارية بلا مقابل.
final downloadWatcherProvider = Provider<void>((ref) {
  final notifications = ref.watch(notificationsProvider);
  final logger = ref.watch(loggerProvider);
  final notified = <String>{};

  /// بصمة آخر إشعار لكل مهمة — بلا هذا المرشّح تُنشر سبع مهام في كل
  /// بثّة (آلاف النداءات في الدقيقة) فيخنقها أندرويد ويتجمد ما يُرى.
  final lastShown = <int, String>{};

  /// تسلسل النشر: نداء قديم كان يصل بعد أحدث منه فيعيد النسبة للوراء.
  Future<void> chain = Future.value();

  MTLocalizations l10n() => lookupMTLocalizations(
      Locale(ref.read(settingsProvider).localeCode ?? 'ar'));

  int idOf(DownloadTask task) => task.id.hashCode & 0x7fffffff;

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
          await showProgressIfChanged(id,
              title: title,
              body: texts.queuedSection,
              channelName: texts.activeDownloads,
              percent: null);
        case TaskPhase.adding:
          await showProgressIfChanged(id,
              title: title,
              body: texts.addingToServer,
              channelName: texts.activeDownloads,
              percent: null);
        case TaskPhase.polling:
          await showProgressIfChanged(id,
              title: title,
              body: texts
                  .onServerProgress((task.progress * 100).toStringAsFixed(0)),
              channelName: texts.activeDownloads,
              percent: (task.progress * 100).round());
        case TaskPhase.waitingForNetwork:
          await showProgressIfChanged(id,
              title: title,
              body: texts.waitingForWifi,
              channelName: texts.activeDownloads,
              percent: null);
        // السحب في Super استثناء («إتاحة دون اتصال» والدفعي) لكنه أطول
        // مرحلة حين يقع، فالنسبة في النص لا في الشريط وحده.
        case TaskPhase.pulling:
          await showProgressIfChanged(id,
              title: title,
              body: texts.pullingToDeviceProgress(
                  (task.progress * 100).toStringAsFixed(0)),
              channelName: texts.activeDownloads,
              percent: (task.progress * 100).round());
        case TaskPhase.deleting:
          await showProgressIfChanged(id,
              title: title,
              body: texts.cleaningServer,
              channelName: texts.activeDownloads,
              percent: null);
        case TaskPhase.completed:
          lastShown.remove(id);
          if (!notified.add(task.id)) break;
          await notifications.cancel(id);
          await notifications.showResult(
            id,
            title: texts.downloadCompleteTitle,
            body: task.title ?? task.effectiveUrl,
            channelName: texts.downloadComplete,
            // النقرة تُبرز العنصر في المكتبة — نفس مسار توهج الاكتمال.
            payload: task.canonicalUrl ?? task.localPath,
          );
        case TaskPhase.failed:
          lastShown.remove(id);
          if (!notified.add(task.id)) break;
          await notifications.cancel(id);
          await notifications.showResult(
            id,
            title: texts.downloadFailedTitle,
            // **سبب الفشل في الإشعار نفسه**: «فشل» وحدها تُبقي المستخدم
            // يخمّن بين شبكة مقطوعة ورابط مرفوض واعتماد خاطئ.
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
  }

  ref.listen<AsyncValue<List<DownloadTask>>>(
    engineTasksProvider,
    (_, next) {
      final tasks = next.valueOrNull ?? const <DownloadTask>[];
      chain = chain.then((_) => handle(tasks)).catchError((Object e) {
        unawaited(
            logger.error('notification failed', cause: e, tag: 'download'));
      });
    },
  );
});

/// يُنادى مرة عند الإقلاع من الغلاف.
///
/// **لا يُخرج عطلاً إلى سلسلة الإقلاع**: نداء المنصة يرمي في بيئة بلا
/// قناة (اختبارات ويدجت، سطح مكتب) وحتى على أجهزة لا تسجّل الملحق —
/// وسلسلة `initState` بعده تحمل استقبال المشاركة والاختصارات، فسقوطها
/// يعطّل ما لا علاقة له بالإشعارات.
Future<void> initDownloadNotifications(WidgetRef ref) async {
  final notifications = ref.read(notificationsProvider);
  try {
    await notifications.init(
      onOpenItem: (key) =>
          ref.read(highlightedItemProvider.notifier).state = key,
    );
    await notifications.requestPermission();
  } on Object catch (e) {
    // التسجيل نفسه دفاعي: السجل قد لا يكون محقوناً في بيئة الاختبار.
    try {
      unawaited(ref
          .read(loggerProvider)
          .error('notifications init failed', cause: e, tag: 'download'));
    } on Object {
      // بيئة بلا سجل — الإشعارات وحدها تغيب والتحميل يعمل.
    }
  }
}
