import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// The automatic backup status line: confidence comes from seeing that the
/// thing is happening.
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
