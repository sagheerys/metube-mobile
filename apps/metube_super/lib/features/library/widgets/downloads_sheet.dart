import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';
import '../../home/add_flow.dart';

/// The "manage downloads" sheet: in progress, waiting, needs your
/// attention, with cancel and retry.
void showDownloadsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    // **It does not rise into the camera cutout** (field report
    // 2026-09-04):
    // without this the sheet started at the very top of the screen, so the
    // drag handle disappeared under the status bar and there was nothing
    // left
    // to grab to pull it down.
    useSafeArea: true,
    builder: (_) => const _DownloadsSheet(),
  );
}

class _DownloadsSheet extends ConsumerWidget {
  const _DownloadsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final tasks = ref.watch(engineTasksProvider).valueOrNull ?? const [];
    final engine = ref.read(downloadEngineProvider);

    final running = tasks
        .where((t) => !t.isFinished && t.phase != TaskPhase.queued)
        .toList();
    final queued = tasks.where((t) => t.phase == TaskPhase.queued).toList();
    final failed = tasks.where((t) => t.phase == TaskPhase.failed).toList();

    Widget section(
      String title,
      List<DownloadTask> sectionTasks, {
      bool error = false,
    }) {
      if (sectionTasks.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MTSectionHeader(title: title, trailing: '${sectionTasks.length}'),
          const SizedBox(height: MTSpace.sm),
          for (final task in sectionTasks) ...[
            MTDownloadProgressCard(
              title: task.effectiveUrl,
              statusText: error
                  ? taskErrorText(l10n, task)
                  : switch (task.phase) {
                      TaskPhase.queued => l10n.queuedSection,
                      // The wait is the user's own decision, not a slow
                      // network.
                      TaskPhase.waitingForNetwork => l10n.waitingForWifi,
                      TaskPhase.pulling => l10n.pullingToDevice,
                      // The percentage is an independent element in the
                      // card and is not repeated here.
                      _ => l10n.onServerPhase,
                    },
              progress: task.hasKnownProgress ? task.progress : null,
              isError: error,
              // **A failed task is dismissed with the same close button**
              // (field report 2026-09-03: "if a file fails to download you
              // cannot remove it from the downloads list"). `onCancel` was
              // null on an error, so the close mark disappeared and only
              // "retry" was left, and the card sat in "needs your
              // attention" until the app was killed. `forget` had been in
              // the engine all along and nothing in the interface called
              // it.
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
                      // The old card does not linger beside the new
                      // attempt.
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

    final shown = tasks.where(
      (t) => !t.isFinished || t.phase == TaskPhase.failed,
    );
    if (shown.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          MTSpace.xl,
          MTSpace.lg,
          MTSpace.xl,
          mtSheetBottomPad(context, MTSpace.xxl),
        ),
        child: MTEmptyState(
          icon: Icons.download_done_rounded,
          title: l10n.noDownloads,
          message: l10n.allDownloadsFinished,
        ),
      );
    }

    // **A fixed height with a scrolling list** (field report 2026-09-04:
    // "the downloads page is now right at the top and you cannot drag it
    // down, and the list shrinks every time a video finishes").
    // `ListView(shrinkWrap: true)` made the sheet's height equal its
    // content's: seven tasks filled the screen, then it jumped upward with
    // every completion. The sheet now opens at 62% and drags between 35%
    // and 85% however the count changes, and only the list scrolls.
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.fromLTRB(
          MTSpace.xl,
          MTSpace.lg,
          MTSpace.xl,
          mtSheetBottomPad(context, MTSpace.xxl),
        ),
        // **The title is pinned and only the list scrolls** (field report
        // 2026-09-04): it used to be the first item in the `ListView`, so
        // it scrolled away with the content and vanished once there were
        // many downloads, leaving a list scrolling with no header to say
        // what it is.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.activeDownloadsSheet,
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
