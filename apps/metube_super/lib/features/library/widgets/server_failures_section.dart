import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../server_failures.dart';

/// The downloads sheet's section for rows the server stopped with an error:
/// each with its reason, a retry and a remove, and for more than one a
/// retry and a remove for them all.
class ServerFailuresSection extends ConsumerStatefulWidget {
  const ServerFailuresSection({super.key, required this.items});

  final List<HistoryItem> items;

  @override
  ConsumerState<ServerFailuresSection> createState() =>
      _ServerFailuresSectionState();
}

class _ServerFailuresSectionState extends ConsumerState<ServerFailuresSection> {
  /// One request at a time: a second tap while the first is on its way
  /// would ask the server about rows it is already removing.
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on MTApiException {
      if (mounted) {
        showMTSnack(context, context.mtl.failed, type: MTSnackType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAll() async {
    final l10n = context.mtl;
    final count = widget.items.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.removeFailedTitle(count)),
        content: Text(l10n.removeFailedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.removeFailed),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      final removed = await ref.read(serverFailureActionsProvider).remove([
        for (final item in widget.items) item.canonicalUrl,
      ]);
      if (mounted) showMTSnack(context, l10n.removedFailed(removed));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final actions = ref.read(serverFailureActionsProvider);
    final items = widget.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MTSectionHeader(
          title: l10n.serverFailuresTitle,
          trailing: '${items.length}',
        ),
        const SizedBox(height: MTSpace.xxs),
        Text(
          l10n.serverFailuresNote,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: p.ink3),
        ),
        if (items.length > 1)
          Wrap(
            alignment: WrapAlignment.end,
            spacing: MTSpace.xs,
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => actions.retry(items)),
                child: Text(l10n.retryAll),
              ),
              TextButton(
                onPressed: _busy ? null : _removeAll,
                style: TextButton.styleFrom(foregroundColor: p.err),
                child: Text(l10n.removeFailed),
              ),
            ],
          ),
        const SizedBox(height: MTSpace.sm),
        for (final item in items) ...[
          MTDownloadProgressCard(
            key: ValueKey('server-failure-${item.canonicalUrl}'),
            // Isolated: a bare link or an English reason inside an Arabic
            // sheet is otherwise reordered ("//:https").
            title: mtName(item.title ?? item.canonicalUrl),
            statusText: switch (failureReason(item)) {
              final reason? => mtName(reason),
              null => l10n.failed,
            },
            isError: true,
            // The close mark removes this one failed row and nothing else;
            // it needs no question, there is no file behind it.
            onCancel: _busy
                ? null
                : () => _run(() => actions.remove([item.canonicalUrl])),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => actions.retry([item])),
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
}

/// One calm line at the top of the library while the server holds failed
/// downloads; a tap opens them in the downloads sheet. Nothing at all
/// otherwise.
class ServerFailuresLine extends ConsumerWidget {
  const ServerFailuresLine({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(serverFailuresProvider).length;
    if (count == 0) return const SizedBox.shrink();
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.sm),
      child: Material(
        color: p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MTRadius.card),
          side: BorderSide(color: p.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(MTRadius.card),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.md,
              vertical: MTSpace.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 18, color: p.err),
                const SizedBox(width: MTSpace.sm),
                Expanded(
                  child: Text(
                    l10n.serverFailuresLine(count),
                    style: text.bodyMedium,
                  ),
                ),
                const SizedBox(width: MTSpace.sm),
                Text(
                  l10n.viewAll,
                  style: text.labelLarge!.copyWith(color: p.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
