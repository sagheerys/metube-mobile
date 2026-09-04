import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';
import '../../home/add_flow.dart';

/// ورقة «إدارة التحميلات» (النموذج أ): جارٍ الآن / بالانتظار /
/// تحتاج انتباهك — مع إلغاء وإعادة محاولة.
void showDownloadsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    // **لا تصعد إلى فتحة الكاميرا** (بلاغ المالك 2026-09-04): بلا هذا
    // كانت الورقة تبدأ من أعلى الشاشة تماماً فيختفي مقبض السحب تحت
    // شريط الحالة ولا يبقى ما يُمسك به لإنزالها.
    useSafeArea: true,
    builder: (_) => const _DownloadsSheet(),
  );
}

class _DownloadsSheet extends ConsumerWidget {
  const _DownloadsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final tasks = ref.watch(engineTasksProvider).value ?? const [];
    final engine = ref.read(downloadEngineProvider);

    final running = tasks
        .where((t) =>
            !t.isFinished &&
            t.phase != TaskPhase.queued)
        .toList();
    final queued =
        tasks.where((t) => t.phase == TaskPhase.queued).toList();
    final failed =
        tasks.where((t) => t.phase == TaskPhase.failed).toList();

    Widget section(String title, List<DownloadTask> sectionTasks,
        {bool error = false}) {
      if (sectionTasks.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MTSectionHeader(
              title: title, trailing: '${sectionTasks.length}'),
          const SizedBox(height: MTSpace.sm),
          for (final task in sectionTasks) ...[
            MTDownloadProgressCard(
              title: task.effectiveUrl,
              statusText: error
                  ? taskErrorText(l10n, task)
                  : switch (task.phase) {
                      TaskPhase.queued => l10n.queuedSection,
                      // م-42: الانتظار سببه قرار المستخدم لا بطء شبكة.
                      TaskPhase.waitingForNetwork => l10n.waitingForWifi,
                      TaskPhase.pulling => l10n.pullingToDevice,
                      // النسبة عنصر مستقل في البطاقة — لا تُكرَّر هنا.
                      _ => l10n.onServerPhase,
                    },
              progress: task.hasKnownProgress ? task.progress : null,
              isError: error,
              // **الفاشلة تُزال بنفس زر الإغلاق** (بلاغ المالك
              // 2026-09-03: «إذا فشل تحميل ملف لا تستطيع إزالته من قائمة
              // التحميلات»). كان `onCancel: null` عند الخطأ فتختفي علامة
              // الإغلاق ولا يبقى إلا «إعادة المحاولة» — فتسكن البطاقة في
              // «تحتاج انتباهك» إلى أن يُقتل التطبيق. `forget` موجود في
              // المحرك منذ م-4 ولم يكن أحد يناديه من الواجهة.
              onCancel: () {
                if (error) {
                  engine?.forget(task.id);
                } else {
                  engine?.cancel(task.id);
                }
              },
            ),
            if (error)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      engine?.submit(task.effectiveUrl, task.quality);
                      // البطاقة القديمة لا تبقى بجانب المحاولة الجديدة.
                      engine?.forget(task.id);
                      Navigator.pop(context);
                    },
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            const SizedBox(height: MTSpace.xs),
          ],
          const SizedBox(height: MTSpace.md),
        ],
      );
    }

    final shown =
        tasks.where((t) => !t.isFinished || t.phase == TaskPhase.failed);
    if (shown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.xl, MTSpace.lg, MTSpace.xl, MTSpace.xxl),
        child: MTEmptyState(
          icon: Icons.download_done_rounded,
          title: l10n.noDownloads,
          message: l10n.allDownloadsFinished,
        ),
      );
    }

    // **ارتفاع ثابت وقائمة تمرّر** (بلاغ المالك 2026-09-04: «صفحة
    // التحميلات صارت في الأعلى تماماً ولا تستطيع سحبها للأسفل، والقائمة
    // تتقلص كلما اكتمل فيديو»). `ListView(shrinkWrap: true)` كان يجعل
    // ارتفاع الورقة = ارتفاع محتواها: سبع مهام ⇒ ملء الشاشة، ثم قفزة
    // لأعلى مع كل اكتمال. الورقة الآن تبدأ عند 62٪ وتُسحب بين 35٪
    // و85٪ مهما تغيّر العدد، والقائمة وحدها هي التي تمرّر.
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.xl, MTSpace.lg, MTSpace.xl, MTSpace.xxl),
        // **العنوان مثبَّت والقائمة وحدها تمرّر** (بلاغ المالك
        // 2026-09-04): كان أولَ عنصر في `ListView`، فيمرّ مع المحتوى
        // ويختفي عند كثرة التحميلات — فتُمرَّر قائمةٌ بلا رأس يقول
        // ما هي.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.activeDownloadsSheet,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: MTSpace.lg),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  section(l10n.activeNow, running),
                  section(l10n.queuedSection, queued),
                  section(l10n.needsAttention, failed, error: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
