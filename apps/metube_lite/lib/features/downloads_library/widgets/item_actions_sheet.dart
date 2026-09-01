import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../playlists/add_to_playlist_sheet.dart';
import '../../shared/error_text.dart';
import '../library_actions.dart';
import '../library_providers.dart';
import '../local_item.dart';

/// ورقة إجراءات العنصر (ر-5 — نسخة Lite: كله محلي) — الحذف أخيراً
/// معزولاً بفاصل وبلون الخطأ (قاعدة تنقل عامة).
void showItemActionsSheet(
    BuildContext context, WidgetRef ref, LocalItem item) {
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

  final LocalItem item;

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
      try {
        await action();
        if (successText != null && host.mounted) {
          showMTSnack(host, successText, type: MTSnackType.success);
        }
      } catch (e) {
        if (host.mounted) {
          showMTSnack(host, errorText(l10n, e), type: MTSnackType.error);
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
            showModalBottomSheet<void>(
              context: host,
              useRootNavigator: true,
              builder: (_) => _DetailsSheet(item: item),
            );
          }),
          tile(Icons.share_rounded, l10n.share,
              () => run(() => actions.share([item]))),
          tile(Icons.playlist_add_rounded, l10n.addToPlaylist, () {
            Navigator.pop(context);
            showAddToPlaylistSheet(host, ref, [item]);
          }),
          // الرابط الأصلي متاح فقط لما نعرف رابطه (لا اختلاق — فخ §6.3).
          if (item.canonicalUrl != null)
            tile(Icons.open_in_new_rounded, l10n.openOriginalLink, () {
              Navigator.pop(context);
              launchUrl(Uri.parse(item.canonicalUrl!),
                  mode: LaunchMode.externalApplication);
            }),
          const Divider(),
          tile(
            Icons.delete_outline_rounded,
            l10n.deleteVideo,
            () => _confirm(context, l10n.deleteVideoConfirm(item.title), () {
              run(() => actions.deleteFiles([item]),
                  successText: l10n.deletedTitle(item.title));
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

/// ورقة التفاصيل (م-16): الاسم والحجم والتاريخ والمنصة والرابط بنسخ بلمسة.
class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({required this.item});

  final LocalItem item;

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
                child:
                    Text(label, style: text.bodySmall!.copyWith(color: p.ink3)),
              ),
              Expanded(child: Text(value, style: text.bodyMedium)),
            ],
          ),
        );

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
            // نفس تصحيح Super: تسميتان خاطئتان إحداهما نص مثبت.
            row(l10n.titleLabel, item.title),
            row(l10n.fileSize,
                '${(item.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'),
            row(l10n.downloadDate, mtTimeAgo(context, item.modified)),
            row(l10n.platform, item.platform.label),
            const SizedBox(height: MTSpace.sm),
            // الرابط الأصلي — نسخ بلمسة (م-16). الملفات المهاجرة من
            // النسخة القديمة لا رابط لها فيُعرض مسارها بدله.
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: item.canonicalUrl ?? item.path));
                if (context.mounted) {
                  showMTSnack(context, l10n.copiedToClipboard);
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(
                item.canonicalUrl ?? item.filename,
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

/// تأكيد الحذف الجماعي (ر-6) — حذف الملفات من الجهاز.
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
            final all = ref.read(localMediaProvider).value ?? const [];
            final targets = [
              for (final item in all)
                if (selection.contains(item.key)) item,
            ];
            try {
              final count =
                  await ref.read(libraryActionsProvider).deleteFiles(targets);
              ref.read(libraryViewProvider.notifier).clearSelection();
              if (context.mounted) {
                showMTSnack(context, l10n.deletedCount(count),
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
