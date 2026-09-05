import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../playlists/add_to_playlist_sheet.dart';
import '../../shared/error_text.dart';
import '../../shared/external_player.dart';
import '../../tags/item_tags_sheet.dart';
import '../library_models.dart';
import '../library_actions.dart';
import '../library_providers.dart';
import 'item_details_sheet.dart';

/// ورقة إجراءات العنصر حسب حالته (ر-5) — الحذف أخيراً معزولاً بفاصل
/// وبلون الخطأ (قاعدة تنقل عامة).
void showItemActionsSheet(
    BuildContext context, WidgetRef ref, LibraryItem item) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    // سياق الشاشة (لا سياق الورقة) يُمرَّر لفتح الأوراق التالية بعده:
    // استعمال سياق ورقة مُغلقة يفجّر تأكيد `_dependents.isEmpty`.
    builder: (_) => _ItemActionsSheet(item: item, host: context),
  );
}

class _ItemActionsSheet extends ConsumerWidget {
  const _ItemActionsSheet({required this.item, required this.host});

  final LibraryItem item;

  /// سياق الشاشة المستضيفة — يبقى حياً بعد إغلاق هذه الورقة.
  final BuildContext host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final actions = ref.read(libraryActionsProvider);

    Future<void> run(Future<void> Function() action,
        {String? successText}) async {
      Navigator.pop(context);
      final messenger = ScaffoldMessenger.maybeOf(context);
      try {
        await action();
        if (successText != null && messenger != null && context.mounted) {
          showMTSnack(context, successText, type: MTSnackType.success);
        }
      } catch (e) {
        if (context.mounted) {
          showMTSnack(context, errorText(l10n, e), type: MTSnackType.error);
        }
      }
    }

    ListTile tile(IconData icon, String label, VoidCallback onTap,
            {Color? color}) =>
        ListTile(
          leading: Icon(icon, color: color ?? p.ink2),
          title: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: color)),
          onTap: onTap,
        );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                MTSpace.xl, MTSpace.lg, MTSpace.xl, MTSpace.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          if (item.onServer && !item.isOffline)
            tile(Icons.download_for_offline_outlined, l10n.makeOffline,
                () => run(() => actions.makeOffline(item),
                    successText: l10n.madeOffline)),
          tile(Icons.info_outline_rounded, l10n.details, () {
            Navigator.pop(context);
            showItemDetailsSheet(host, item);
          }),
          tile(Icons.share_rounded, l10n.share,
              () => run(() => actions.smartShare(item))),
          // **المشغل الخارجي للنسخة المحلية وحدها** (قرار المالك
          // 2026-09-05): سيرفر Super بلا استيثاق، فتسليم رابط بثّ
          // لتطبيق آخر يعني وصولاً مفتوحاً لمن يقرأ سجلّه. العنصر
          // الذي لا نسخة له يرى «أتِح دون اتصال» أعلاه بدل هذا.
          if (item.localPath case final String path)
            tile(Icons.open_with_rounded, l10n.openInExternalPlayer,
                () => run(() async {
                      final opened = await const ExternalPlayer()
                          .open(path, audio: item.isAudio);
                      if (!opened && host.mounted) {
                        showMTSnack(host, l10n.noExternalPlayer,
                            type: MTSnackType.error);
                      }
                    })),
          // **كان ناقصاً في Super** (بلاغ المالك 2026-09-05) — موجود
          // في Lite منذ م-20.
          tile(Icons.open_in_new_rounded, l10n.openOriginalLink, () {
            Navigator.pop(context);
            launchUrl(Uri.parse(item.canonicalUrl),
                mode: LaunchMode.externalApplication);
          }),
          tile(Icons.playlist_add_rounded, l10n.addToPlaylist, () {
            Navigator.pop(context);
            showAddToPlaylistSheet(host, ref, [item]);
          }),
          tile(Icons.sell_outlined, l10n.tags, () {
            Navigator.pop(context);
            showItemTagsSheet(host, ref, [item.canonicalUrl]);
          }),
          if (item.isOffline && item.onServer)
            tile(Icons.phonelink_erase_rounded, l10n.removeLocalCopy,
                () => run(() => actions.removeLocalCopy(item),
                    successText: l10n.localCopyRemoved)),
          const Divider(),
          if (item.onServer)
            tile(Icons.delete_outline_rounded, l10n.deleteFromServer,
                () => _confirm(context, l10n.deleteFromServerConfirm, () {
                      run(
                          () => actions
                              .deleteFromServer([item.canonicalUrl]),
                          successText: l10n.deletedFromServer);
                    }),
                color: p.err),
          if (!item.onServer && item.isOffline)
            tile(Icons.delete_outline_rounded, l10n.deleteVideo,
                () => _confirm(
                        context, l10n.deleteVideoConfirm(item.title), () {
                      run(() => actions.deleteLocalOnly(item),
                          successText: l10n.deletedTitle(item.title));
                    }),
                color: p.err),
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

/// تأكيد الحذف الجماعي (ر-6) — حذف من السيرفر بالمُقنون.
void confirmBulkDelete(
    BuildContext context, WidgetRef ref, Set<String> selection) {
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
            final actions = ref.read(libraryActionsProvider);
            try {
              await actions.deleteFromServer(selection.toList());
              ref.read(libraryViewProvider.notifier).clearSelection();
              if (context.mounted) {
                showMTSnack(context, l10n.deletedFromServer,
                    type: MTSnackType.success);
              }
            } catch (e) {
              if (context.mounted) {
                showMTSnack(context, errorText(l10n, e),
                    type: MTSnackType.error);
              }
            }
          },
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
}
