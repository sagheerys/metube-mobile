import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../di.dart';
import '../downloads_library/library_providers.dart';
import '../playlists/playlists_providers.dart';
import '../shared/error_report.dart';
import 'auto_backup.dart';
import 'widgets/backup_picker.dart';

/// Backup and restore: **plain text, rotating, with no key** (decision
/// 2026-09-04). Seven dated copies that refresh themselves, a restore from
/// any of them, and an export for sharing.
///
/// **The concept of a backup key was removed from the product entirely**
/// (decided the same day): no export, no import, and no "keep it like a
/// password" warning. The backup is no longer encrypted, and what does not
/// exist can be neither forgotten nor lost.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  List<BackupFile> _backups = const [];

  BackupService get _service => ref.read(backupServiceProvider);
  AutoBackup get _backup => ref.read(autoBackupProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_refreshList());
  }

  Future<void> _refreshList() async {
    final all = await _backup.list();
    if (mounted) setState(() => _backups = all);
  }

  Future<void> _run(
    Future<String> Function(MTLocalizations l10n) action,
  ) async {
    final l10n = context.mtl;
    setState(() => _busy = true);
    try {
      final message = await action(l10n);
      if (mounted) showMTSnack(context, message, type: MTSnackType.success);
    } on BackupCancelledException {
      // A user cancelling is not an error.
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, ref, e, tag: 'backup');
      }
    } finally {
      await _refreshList();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// **Read through the system picker (SAF):** Android 11+ refuses to read
  /// a file the app did not create, even in the same folder (`errno 13`),
  /// and a migration backup comes from another device by definition.
  Future<String?> _pickFileContents() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.singleOrNull;
    if (file == null) return null;
    if (file.bytes case final Uint8List bytes) return utf8.decode(bytes);
    final path = file.path;
    return path == null ? null : File(path).readAsString();
  }

  /// **An export for sharing is a separate file from the rotation**: a
  /// dated name with the share chooser opening on it immediately, which is
  /// its only purpose. Conflating it with the automatic backup made "back
  /// up now" overwrite a file while suggesting it had exported it.
  Future<String> _exportAndShare(MTLocalizations l10n) async {
    final stamp = BackupRotation.stampOf(DateTime.now());
    final file = File('$liteBackupDir/share_${liteBackupPrefix}_$stamp.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(await _service.exportToString(), flush: true);
    await Share.shareXFiles([XFile(file.path)]);
    return l10n.backupSuccess(file.path);
  }

  Future<String> _importPicked(MTLocalizations l10n) async {
    final contents = await _pickFileContents();
    if (contents == null) throw const BackupCancelledException();
    return _applyRestore(l10n, await _service.importFromString(contents));
  }

  Future<String> _restoreFrom(MTLocalizations l10n, BackupFile file) async =>
      _applyRestore(l10n, await _backup.restore(file));

  Future<String> _applyRestore(
    MTLocalizations l10n,
    ImportResult result,
  ) async {
    await _refreshEverything();
    return '${l10n.restoreSuccess} · ${result.keysRestored}';
  }

  /// Everything the backup may have changed is reloaded (rule 8, step 1).
  Future<void> _refreshEverything() async {
    await ref.read(settingsProvider.notifier).reloadFromStore();
    ref.invalidate(localMediaProvider);
    ref.invalidate(playlistsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;

    ListTile tile(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
    ) => ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !_busy,
      leading: Icon(icon, color: p.ink2),
      title: Text(title),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          MTSpace.pagePad,
          0,
          MTSpace.pagePad,
          MTSpace.xxl,
        ),
        children: [
          // **No section header repeating the screen title** (review
          // 2026-09-05): the app bar says "back up all data" and directly
          // beneath it sat "backup and restore", two lines with one
          // meaning.
          const SizedBox(height: MTSpace.md),
          BackupStatusLine(backups: _backups),
          const SizedBox(height: MTSpace.md),
          tile(
            Icons.ios_share_rounded,
            l10n.exportShare,
            l10n.exportShareSubtitle,
            () => _run(_exportAndShare),
          ),
          tile(
            Icons.folder_open_rounded,
            l10n.pickAnotherFile,
            l10n.pickAnotherFileSubtitle,
            () => _run(_importPicked),
          ),
          const SizedBox(height: MTSpace.lg),
          // **The copies are shown rather than hidden behind a button**
          // (review 2026-09-05): two thirds of the screen was empty and the
          // only useful information, when each copy was made and how large
          // it is, sat behind a sheet with nothing to hint at it.
          MTSectionHeader(title: l10n.restoreData),
          const SizedBox(height: MTSpace.sm),
          if (_backups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MTSpace.md),
              child: Text(
                l10n.noBackupsYet,
                style: Theme.of(context).textTheme.bodySmall!
                    .copyWith(color: p.ink3),
              ),
            )
          else
            for (final (index, file) in _backups.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !_busy,
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
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run((l10n) => _restoreFrom(l10n, file)),
                  child: Text(l10n.restoreData),
                ),
              ),
          const SizedBox(height: MTSpace.lg),
          Text(
            l10n.backupNote,
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: p.ink3),
          ),
        ],
      ),
    );
  }
}

/// The user cancelled the file picker: a quiet message, not a loud error.
class BackupCancelledException implements Exception {
  const BackupCancelledException();
}
