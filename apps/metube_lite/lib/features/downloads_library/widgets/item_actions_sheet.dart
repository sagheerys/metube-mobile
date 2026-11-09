import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../playlists/add_to_playlist_sheet.dart';
import '../../shared/error_report.dart';
import '../../shared/external_player.dart';
import '../artwork_view.dart';
import '../library_actions.dart';
import '../library_providers.dart';
import '../local_item.dart';
import 'item_details_sheet.dart';
import '../../shared/open_web_link.dart';

/// The item actions sheet (rule 5, Lite's version where everything is
/// local). Delete comes last, isolated by a divider and in the error
/// colour, which is a general navigation rule.
void showItemActionsSheet(BuildContext context, WidgetRef ref, LocalItem item) {
  showMTSheet<void>(
    context: context,
    useRootNavigator: true,
    // As tall as its rows, not the default nine sixteenths of the screen,
    // which hid Delete below a scroll once the menu grew a row. It still
    // scrolls on a phone too short for all of them.
    isScrollControlled: true,
    useSafeArea: true,
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
      MTIconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) => ListTile(
      leading: MTIcon(icon, color: color ?? p.ink2),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: color),
      ),
      onTap: onTap,
    );

    // Scrolls when it outgrows the sheet: a sheet stops at nine sixteenths
    // of the screen, and on a short phone the last rows, delete among
    // them, were cut off.
    return SafeArea(
      child: SingleChildScrollView(
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
              child: MTForeignText(
                item.title,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            // **Favourites from the menu, not an empty heart on every card**
            // (owner's decision 2026-11-01): the card shows a small heart on
            // favourites alone, and the players keep the one-tap heart.
            MTFavoriteTile(
              favorite: item.favorite,
              onTap: () async {
                Navigator.pop(context);
                final added = await actions.toggleFavorite(item.key);
                if (host.mounted) {
                  showMTSnack(
                    host,
                    added ? l10n.addedToFavorites : l10n.removedFromFavorites,
                  );
                }
              },
            ),
            tile(MTIcons.info, l10n.details, () {
              Navigator.pop(context);
              showItemDetailsSheet(host, item);
            }),
            tile(
              MTIcons.share,
              l10n.share,
              () => run(() => actions.share(host, [item])),
            ),
            // An external player gets a file path: Lite has only local
            // files, so no server URL ever leaves the app.
            tile(
              MTIcons.playback,
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
            tile(MTIcons.queueAdd, l10n.addToPlaylist, () {
              Navigator.pop(context);
              showAddToPlaylistSheet(host, ref, [item]);
            }),
            // The original link is offered only where we know it; it is never
            // rebuilt from a guess.
            if (item.canonicalUrl != null)
              tile(MTIcons.external, l10n.openOriginalLink, () {
                Navigator.pop(context);
                openWebLink(item.canonicalUrl);
              }),
            const Divider(),
            tile(
              MTIcons.trash,
              l10n.deleteVideo,
              () => _confirm(
                context,
                l10n.deleteVideo,
                l10n.deleteVideoConfirm(mtName(item.title)),
                MTDialogClip(
                  title: mtName(item.title),
                  thumbnail: artworkFor(item.thumbnail, decodeWidth: 120),
                ),
                () {
                  run(
                    () => actions.deleteFiles([item]),
                    successText: l10n.deletedTitle(mtName(item.title)),
                  );
                },
              ),
              color: p.err,
            ),
            const SizedBox(height: MTSpace.md),
          ],
        ),
      ),
    );
  }

  /// **The clip itself is shown before anything is deleted** (the Wahaj
  /// confirmation, as on the computer), so nobody removes the wrong one of
  /// two look-alike titles.
  Future<void> _confirm(
    BuildContext context,
    String title,
    String message,
    Widget clip,
    VoidCallback onYes,
  ) async {
    final l10n = context.mtl;
    final sure = await showMTConfirm(
      context,
      title: title,
      message: message,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
      preview: clip,
    );
    if (sure) onYes();
  }
}

/// Bulk delete confirmation (rule 6): deletes the files from the device.
void confirmBulkDelete(
  BuildContext context,
  WidgetRef ref,
  Set<String> selection,
) {
  final l10n = context.mtl;
  showMTDialog<void>(
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
