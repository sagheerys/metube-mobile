import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../settings/auto_backup.dart';
import '../settings/widgets/help_button.dart';
import '../shared/error_report.dart';
import 'transcripts_state.dart';

/// The settings section for searching inside clips: the switch, and once
/// it is on, what it holds and what can be done with it.
class TranscriptsSection extends ConsumerWidget {
  const TranscriptsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final enabled = ref.watch(transcriptsEnabledProvider).valueOrNull ?? false;
    final stats = ref.watch(transcriptStatsProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // What the switch's one line cannot say: YouTube only, kept on
        // this phone and not in the backup, and how to move them.
        MTSectionHeader(
          title: l10n.transcriptsSection,
          action: HelpButton(
            title: l10n.transcriptsSection,
            body: l10n.transcriptsHelp,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.transcriptsSearch, style: text.bodyMedium),
          subtitle: Text(l10n.transcriptsSearchHelp, style: text.bodySmall),
          value: enabled,
          onChanged: (on) =>
              on ? _turnOn(context, ref) : _turnOff(context, ref),
        ),
        if (enabled && stats != null) ...[
          Text(
            mtMetaLine([
              l10n.transcriptsClips(stats.clips),
              if (stats.bytes > 0) mtFormatSize(stats.bytes),
            ]),
            style: text.bodySmall!.copyWith(
              color: MTThemeX.of(context).palette.ink3,
            ),
          ),
          const SizedBox(height: MTSpace.xs),
          Wrap(
            spacing: MTSpace.xs,
            children: [
              TextButton.icon(
                onPressed: stats.clips == 0
                    ? null
                    : () => _export(context, ref),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(l10n.transcriptsExport),
              ),
              TextButton.icon(
                onPressed: () => _import(context, ref),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(l10n.transcriptsImport),
              ),
              TextButton.icon(
                onPressed: stats.clips == 0
                    ? null
                    : () => _deleteAll(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(l10n.transcriptsDeleteAll),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _turnOn(BuildContext context, WidgetRef ref) async {
    final l10n = context.mtl;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.transcriptsSearch),
        content: Text(l10n.transcriptsEnableBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.transcriptsEnable),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(transcriptsEnabledProvider.notifier).set(true);
    }
  }

  /// Turning off keeps the transcripts unless asked otherwise: they cost
  /// a server round trip each to fetch again, and some can no longer be.
  Future<void> _turnOff(BuildContext context, WidgetRef ref) async {
    final l10n = context.mtl;
    final bytes = ref.read(transcriptStatsProvider).valueOrNull?.bytes ?? 0;
    final choice = await showDialog<_OffChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.transcriptsDisableTitle),
        content: Text(l10n.transcriptsDisableBody(mtFormatSize(bytes))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _OffChoice.delete),
            child: Text(l10n.transcriptsStopAndDelete),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _OffChoice.keep),
            child: Text(l10n.transcriptsKeep),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == _OffChoice.delete) {
      await ref.read(transcriptsServiceProvider).deleteAll();
    }
    await ref.read(transcriptsEnabledProvider.notifier).set(false);
  }

  /// Written beside the settings backups, a folder that outlives the app,
  /// then handed to the share sheet.
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = context.mtl;
    try {
      final stamp = BackupRotation.stampOf(DateTime.now());
      final file = File('$superBackupDir/transcripts_$stamp.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        await ref.read(transcriptsServiceProvider).exportAll(),
        flush: true,
      );
      await Share.shareXFiles([XFile(file.path)]);
      if (context.mounted) {
        showMTSnack(
          context,
          l10n.transcriptsExported(mtLtrRun(file.path)),
          type: MTSnackType.success,
        );
      }
    } on Object catch (e) {
      if (context.mounted) showErrorSnack(context, ref, e, tag: 'transcripts');
    }
  }

  /// Through the system picker: Android refuses to read a file the app did
  /// not create, and an export comes from another phone by definition.
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = context.mtl;
    try {
      final picked = await FilePicker.platform.pickFiles(withData: true);
      final file = picked?.files.singleOrNull;
      if (file == null) return;
      final raw = switch (file.bytes) {
        final Uint8List bytes => utf8.decode(bytes, allowMalformed: true),
        null when file.path != null => await File(file.path!).readAsString(),
        null => null,
      };
      if (raw == null) return;
      final count = await ref.read(transcriptsServiceProvider).importAll(raw);
      if (!context.mounted) return;
      showMTSnack(
        context,
        count == null
            ? l10n.transcriptsImportInvalid
            : l10n.transcriptsImported(count),
        type: count == null ? MTSnackType.error : MTSnackType.success,
      );
    } on Object catch (e) {
      if (context.mounted) showErrorSnack(context, ref, e, tag: 'transcripts');
    }
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final l10n = context.mtl;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.transcriptsDeleteTitle),
        content: Text(l10n.transcriptsDeleteBody),
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
    if (confirmed ?? false) {
      await ref.read(transcriptsServiceProvider).deleteAll();
    }
  }
}

enum _OffChoice { keep, delete }
