import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/library_providers.dart';
import '../playlists/playlists_providers.dart';

/// «إدارة الوسوم» (م-26 · ر-7 خطوة 3): إعادة تسمية وحذف وسم فقط —
/// **حذف الوسم لا يحذف الوسائط أبداً**.
void showManageTagsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const _ManageTagsSheet(),
  );
}

class _ManageTagsSheet extends ConsumerWidget {
  const _ManageTagsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final counts = ref.watch(tagCountsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(MTSpace.pagePad),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MTSectionHeader(
                title: l10n.manageTags,
                trailing: l10n.tagActionsHint,
              ),
              const SizedBox(height: MTSpace.sm),
              Flexible(
                child: counts.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Text(l10n.tryAgain),
                  data: (map) => map.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(MTSpace.xl),
                          child: Text(l10n.noTagsYet,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final tag in map.keys.toList()..sort())
                              _TagRow(
                                tag: tag,
                                count: map[tag]!,
                                palette: p,
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagRow extends ConsumerWidget {
  const _TagRow({
    required this.tag,
    required this.count,
    required this.palette,
  });

  final String tag;
  final int count;
  final MTPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('# $tag'),
      subtitle: Text(l10n.queueItemsCount(count)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.renameTag,
            onPressed: () => _rename(context, ref),
            icon: Icon(Icons.edit_rounded, size: 19, color: palette.ink2),
          ),
          IconButton(
            tooltip: l10n.deleteTag,
            onPressed: () => _delete(context, ref),
            icon: Icon(Icons.delete_outline_rounded,
                size: 19, color: palette.err),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final l10n = context.mtl;
    // المتحكم يملكه الحوار ويصرّفه — راجع `mt_text_prompt.dart`.
    final name = await promptMTText(
      context,
      title: l10n.renameTag,
      confirmLabel: l10n.rename,
      initialValue: tag,
      hintText: l10n.newTagHint,
    );
    if (name == null || name.isEmpty || name == tag) return;
    await ref.read(tagsIndexProvider).renameTag(tag, name);
    _refresh(ref);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.mtl;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.deleteTagConfirm(tag)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(tagsIndexProvider).deleteTag(tag);
    _refresh(ref);
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(tagCountsProvider);
    ref.invalidate(libraryItemsProvider);
  }
}
