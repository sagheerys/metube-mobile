import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../playlists/add_to_playlist_sheet.dart';
import '../../shared/error_report.dart';
import '../../shared/external_player.dart';
import '../library_actions.dart';
import '../library_providers.dart';
import '../local_item.dart';
import 'item_details_sheet.dart';

/// The item actions sheet (rule 5, Lite's version where everything is
/// local). Delete comes last, isolated by a divider and in the error
/// colour, which is a general navigation rule.
void showItemActionsSheet(BuildContext context, WidgetRef ref, LocalItem item) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    // The screen's context, not the sheet's, is passed for opening later
    // sheets: using a closed sheet's context trips the
    // `_dependents.isEmpty`
    // assertion.
    builder: (_) => _ItemActionsSheet(item: item, host: context),
  );
}

class _ItemActionsSheet extends ConsumerWidget {
  const _ItemActionsSheet({required this.item, required this.host});

  final LocalItem item;

  /// The hosting screen's context, which stays alive after this sheet
  /// closes.
  final BuildContext host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final actions = ref.read(libraryActionsProvider);

    Future<void> run(
      Future<void> Function() action, {
      String? successText,
    }) async {
      Navigator.pop(context);
      try {
        await action();
        if (successText != null && host.mounted) {
          showMTSnack(host, successText, type: MTSnackType.success);
        }
      } catch (e) {
        if (host.mounted) {
          showErrorSnack(host, ref, e, tag: 'library');
        }
      }
    }

    ListTile tile(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) => ListTile(
      leading: Icon(icon, color: color ?? p.ink2),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: color),
      ),
      onTap: onTap,
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MTSpace.xl,
              MTSpace.lg,
              MTSpace.xl,
              MTSpace.sm,
            ),
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          tile(Icons.info_outline_rounded, l10n.details, () {
            Navigator.pop(context);
            showItemDetailsSheet(host, item);
          }),
          tile(
            Icons.share_rounded,
            l10n.share,
            () => run(() => actions.share([item])),
          ),
          // **An external player, for a local file only** (requested
          // 2026-09-05).
          tile(
            Icons.open_with_rounded,
            l10n.openInExternalPlayer,
            () => run(() async {
              final opened = await const ExternalPlayer().open(
                item.path,
                audio: item.isAudio,
              );
              if (!opened && host.mounted) {
                showMTSnack(
                  host,
                  l10n.noExternalPlayer,
                  type: MTSnackType.error,
                );
              }
            }),
          ),
          tile(Icons.playlist_add_rounded, l10n.addToPlaylist, () {
            Navigator.pop(context);
            showAddToPlaylistSheet(host, ref, [item]);
          }),
          // The original link is offered only where we know it; it is never
          // invented (trap §6.3).
          if (item.canonicalUrl != null)
            tile(Icons.open_in_new_rounded, l10n.openOriginalLink, () {
              Navigator.pop(context);
              launchUrl(
                Uri.parse(item.canonicalUrl!),
                mode: LaunchMode.externalApplication,
              );
            }),
          const Divider(),
          tile(
            Icons.delete_outline_rounded,
            l10n.deleteVideo,
            () => _confirm(context, l10n.deleteVideoConfirm(item.title), () {
              run(
                () => actions.deleteFiles([item]),
                successText: l10n.deletedTitle(item.title),
              );
            }),
            color: p.err,
          ),
          const SizedBox(height: MTSpace.md),
        ],
      ),
    );
  }

  void _confirm(BuildContext context, String message, VoidCallback onYes) {
    final l10n = context.mtl;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onYes();
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

/// Bulk delete confirmation (rule 6): deletes the files from the device.
void confirmBulkDelete(
  BuildContext context,
  WidgetRef ref,
  Set<String> selection,
) {
  final l10n = context.mtl;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(l10n.deleteMultipleConfirm(selection.length)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            final all = ref.read(localMediaProvider).valueOrNull ?? const [];
            final targets = [
              for (final item in all)
                if (selection.contains(item.key)) item,
            ];
            try {
              final count = await ref
                  .read(libraryActionsProvider)
                  .deleteFiles(targets);
              ref.read(libraryViewProvider.notifier).clearSelection();
              if (context.mounted) {
                showMTSnack(
                  context,
                  l10n.deletedCount(count),
                  type: MTSnackType.success,
                );
              }
            } catch (e) {
              if (context.mounted) {
                showErrorSnack(context, ref, e, tag: 'library');
              }
            }
          },
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
}
