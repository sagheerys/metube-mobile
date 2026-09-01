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
                  : task.phase == TaskPhase.queued
                      ? l10n.queuedSection
                      : l10n.onServerProgress(
                          (task.progress * 100).toStringAsFixed(0)),
              progress:
                  task.phase == TaskPhase.queued ? null : task.progress,
              isError: error,
              onCancel: error
                  ? null
                  : () => engine?.cancel(task.id),
            ),
            if (error)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      engine?.submit(task.effectiveUrl, task.quality);
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MTSpace.xl, MTSpace.lg, MTSpace.xl, MTSpace.xxl),
      child: tasks.where((t) => !t.isFinished || t.phase == TaskPhase.failed)
              .isEmpty
          ? MTEmptyState(
              icon: Icons.download_done_rounded,
              title: l10n.noDownloads,
              message: l10n.allDownloadsFinished,
            )
          : ListView(
              shrinkWrap: true,
              children: [
                Text(l10n.activeDownloadsSheet,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: MTSpace.lg),
                section(l10n.activeNow, running),
                section(l10n.queuedSection, queued),
                section(l10n.needsAttention, failed, error: true),
              ],
            ),
    );
  }
}
