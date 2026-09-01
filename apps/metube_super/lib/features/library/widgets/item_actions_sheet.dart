import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shared/error_text.dart';
import '../library_models.dart';
import '../library_actions.dart';
import '../library_providers.dart';

/// ورقة إجراءات العنصر حسب حالته (ر-5) — الحذف أخيراً معزولاً بفاصل
/// وبلون الخطأ (قاعدة تنقل عامة). الوسوم والقوائم تُضاف في المرحلة 6.
void showItemActionsSheet(
    BuildContext context, WidgetRef ref, LibraryItem item) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => _ItemActionsSheet(item: item),
  );
}

class _ItemActionsSheet extends ConsumerWidget {
  const _ItemActionsSheet({required this.item});

  final LibraryItem item;

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
            _showDetails(context, l10n, item);
          }),
          tile(Icons.share_rounded, l10n.share,
              () => run(() => actions.smartShare(item))),
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

  /// ورقة التفاصيل (م-16): الاسم والحجم والتاريخ والمنصة والرابط بنسخ بلمسة.
  void _showDetails(
      BuildContext context, MTLocalizations l10n, LibraryItem item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _DetailsSheet(item: item),
    );
  }
}

class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final p = MTThemeX.of(context).palette;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: MTSpace.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(label,
                    style: text.bodySmall!.copyWith(color: p.ink3)),
              ),
              Expanded(child: Text(value, style: text.bodyMedium)),
            ],
          ),
        );

    final sizeMb = item.sizeBytes == null
        ? null
        : (item.sizeBytes! / (1024 * 1024)).toStringAsFixed(1);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.xl, MTSpace.lg, MTSpace.xl, MTSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MTSectionHeader(title: l10n.details),
            const SizedBox(height: MTSpace.sm),
            row(l10n.details, item.title),
            if (sizeMb != null) row('MB', sizeMb),
            if (item.timestamp != null)
              row(l10n.downloadDate, mtTimeAgo(context, item.timestamp!)),
            row(l10n.availability, [
              if (item.isOffline) l10n.availabilityOffline,
              if (item.onServer) l10n.availabilityServer,
            ].join(' + ')),
            const SizedBox(height: MTSpace.sm),
            // الرابط الأصلي — نسخ بلمسة (م-16).
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: item.canonicalUrl));
                if (context.mounted) {
                  showMTSnack(context, l10n.settingsSaved);
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(
                item.canonicalUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
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
