import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// اختيار المستخدم من ورقة الاستعادة: نسخة بعينها، أو ملف من الخارج.
class BackupPick {
  const BackupPick.file(BackupFile this.file);
  const BackupPick.external() : file = null;

  final BackupFile? file;
}

/// **الاستعادة تعرض التواريخ ولا تخمّن** (قرار المالك 2026-09-04):
/// «استعادة» عمياء لآخر ملف كانت تمنع الرجوع لنسخة أقدم حين تكون
/// الأحدث هي المشكلة — وهو سبب الاحتفاظ بسبع أصلاً.
Future<BackupPick?> showBackupPickerSheet(
  BuildContext context,
  List<BackupFile> backups,
) =>
    showModalBottomSheet<BackupPick>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _BackupPickerSheet(backups: backups),
    );

class _BackupPickerSheet extends StatelessWidget {
  const _BackupPickerSheet({required this.backups});

  final List<BackupFile> backups;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.xl, MTSpace.lg, MTSpace.xl, MTSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MTSectionHeader(title: l10n.restoreData),
            const SizedBox(height: MTSpace.sm),
            if (backups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: MTSpace.md),
                child: Text(l10n.noBackupsYet,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(color: p.ink3)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: backups.length,
                  itemBuilder: (context, index) {
                    final file = backups[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        index == 0
                            ? Icons.history_toggle_off_rounded
                            : Icons.history_rounded,
                        color: index == 0 ? p.accent : p.ink3,
                      ),
                      title: Text(mtTimeAgo(context, file.at)),
                      subtitle: Text(
                        '${(file.sizeBytes / 1024).toStringAsFixed(1)} KB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () => Navigator.pop(
                          context, BackupPick.file(file)),
                    );
                  },
                ),
              ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.folder_open_rounded, color: p.ink2),
              title: Text(l10n.pickAnotherFile),
              subtitle: Text(l10n.pickAnotherFileSubtitle,
                  style: Theme.of(context).textTheme.bodySmall),
              onTap: () =>
                  Navigator.pop(context, const BackupPick.external()),
            ),
          ],
        ),
      ),
    );
  }
}

/// سطر حالة النسخ التلقائية — الثقة تأتي من رؤية أن الشيء يحدث.
class BackupStatusLine extends StatelessWidget {
  const BackupStatusLine({super.key, required this.backups});

  final List<BackupFile> backups;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme.bodySmall!.copyWith(color: p.ink3);

    return Row(
      children: [
        Icon(Icons.autorenew_rounded, size: 16, color: p.ink3),
        const SizedBox(width: MTSpace.xs),
        Expanded(
          child: Text(
            backups.isEmpty
                ? l10n.noBackupsYet
                : '${l10n.lastBackup(mtTimeAgo(context, backups.first.at))}'
                    ' · ${l10n.backupsKept(backups.length)}',
            style: text,
          ),
        ),
      ],
    );
  }
}
