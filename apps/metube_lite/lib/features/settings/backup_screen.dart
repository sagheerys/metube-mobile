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
import '../shared/error_text.dart';
import 'auto_backup.dart';
import 'widgets/backup_picker.dart';

/// النسخ الاحتياطي (م-31 · ر-8) — **نصّي دوّار بلا مفتاح** (قرار المالك
/// 2026-09-04): سبع نسخ مؤرَّخة تتجدد وحدها، واستعادة من أيّها، وتصدير
/// للمشاركة. قراءة النسخ المشفّرة القديمة تبقى للهجرة.
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

  Future<void> _run(Future<String> Function(MTLocalizations l10n) action) async {
    final l10n = context.mtl;
    setState(() => _busy = true);
    try {
      final message = await action(l10n);
      if (mounted) showMTSnack(context, message, type: MTSnackType.success);
    } on BackupCancelledException {
      // إلغاء المستخدم ليس خطأ.
    } catch (e) {
      if (mounted) {
        showMTSnack(context, errorText(l10n, e), type: MTSnackType.error);
      }
    } finally {
      await _refreshList();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// **يُقرأ عبر منتقي النظام (SAF):** أندرويد 11+ يرفض قراءة ملف لم
  /// ينشئه التطبيق ولو كان في نفس المجلد (`errno 13`) — ونسخة الهجرة
  /// تأتي من جهاز آخر بطبيعتها (م-31).
  Future<String?> _pickFileContents() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.singleOrNull;
    if (file == null) return null;
    if (file.bytes case final Uint8List bytes) return utf8.decode(bytes);
    final path = file.path;
    return path == null ? null : File(path).readAsString();
  }

  /// **التصدير للمشاركة ملفٌ مستقل عن الدوّار**: اسمٌ مؤرَّخ يُفتح عليه
  /// اختيار المشاركة فوراً — هذا هدفه الوحيد. الخلط بينه وبين النسخة
  /// التلقائية كان يجعل «انسخ الآن» يدهس ملفاً ويوهم أنه صدّره.
  Future<String> _exportAndShare(MTLocalizations l10n) async {
    final stamp = BackupRotation.stampOf(DateTime.now());
    final file =
        File('$liteBackupDir/share_${liteBackupPrefix}_$stamp.json');
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
      MTLocalizations l10n, ImportResult result) async {
    await _refreshEverything();
    return '${l10n.restoreSuccess} · ${result.keysRestored}';
  }

  Future<String> _importKey(MTLocalizations l10n) async {
    final contents = await _pickFileContents();
    if (contents == null) throw const BackupCancelledException();
    if (!await _service.importKeyFile(contents)) {
      throw const BackupFormatException('bad key file');
    }
    return l10n.keyImported;
  }

  /// كل ما قد تكون النسخة غيّرته يُعاد تحميله (ر-8 خطوة 1).
  Future<void> _refreshEverything() async {
    await ref.read(settingsProvider.notifier).reloadFromStore();
    ref.invalidate(localMediaProvider);
    ref.invalidate(playlistsProvider);
  }

  Future<void> _openRestoreSheet() async {
    final chosen = await showBackupPickerSheet(context, _backups);
    if (chosen == null || !mounted) return;
    await switch (chosen) {
      BackupPick(:final file?) => _run((l10n) => _restoreFrom(l10n, file)),
      _ => _run(_importPicked),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;

    ListTile tile(IconData icon, String title, String subtitle,
            VoidCallback onTap) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: !_busy,
          leading: Icon(icon, color: p.ink2),
          title: Text(title),
          subtitle:
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.pagePad, 0, MTSpace.pagePad, MTSpace.xxl),
        children: [
          MTSectionHeader(title: l10n.backupRestore),
          const SizedBox(height: MTSpace.sm),
          BackupStatusLine(backups: _backups),
          const SizedBox(height: MTSpace.md),
          tile(Icons.restore_rounded, l10n.restoreData,
              l10n.restoreFromBackupSubtitle, _openRestoreSheet),
          tile(Icons.ios_share_rounded, l10n.exportShare,
              l10n.exportShareSubtitle, () => _run(_exportAndShare)),
          const SizedBox(height: MTSpace.xl),
          MTSectionHeader(title: l10n.migrationSection),
          const SizedBox(height: MTSpace.sm),
          tile(Icons.vpn_key_outlined, l10n.importLegacyKey,
              l10n.importLegacyKeySubtitle, () => _run(_importKey)),
          const SizedBox(height: MTSpace.lg),
          Text(l10n.backupNote,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: p.ink3)),
        ],
      ),
    );
  }
}

/// ألغى المستخدم منتقي الملفات — رسالة هادئة لا خطأ صارخ.
class BackupCancelledException implements Exception {
  const BackupCancelledException();
}
