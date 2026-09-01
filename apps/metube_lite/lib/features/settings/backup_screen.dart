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
import '../downloads_library/local_item.dart';
import '../playlists/playlists_providers.dart';
import '../shared/error_text.dart';
import 'auto_backup.dart';

/// النسخ الاحتياطي المشفر (م-31 · ر-8): تصدير/استيراد نسخة v2 وتصدير/
/// استيراد المفتاح، مع قراءة `MTBACKUP1` و`MTSBACKUP1` القديمتين.
/// وLite وحده يكتب **نسخة تلقائية** بعد كل تغيير بيانات.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  static const String _keyFileName = 'metube_lite_backup_key.txt';

  BackupService get _service => ref.read(backupServiceProvider);

  Future<void> _run(Future<String> Function(MTLocalizations l10n) action) async {
    final l10n = context.mtl;
    setState(() => _busy = true);
    try {
      final message = await action(l10n);
      if (mounted) {
        showMTSnack(context, message, type: MTSnackType.success);
      }
    } on BackupCancelledException {
      // إلغاء المستخدم ليس خطأ.
    } catch (e) {
      if (mounted) {
        showMTSnack(context, errorText(l10n, e), type: MTSnackType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// التصدير اليدوي يكتب **نفس ملف النسخة التلقائية** — ملف واحد لا
  /// يتشعّب، وهو ما يقرؤه عرض الاستعادة بعد إعادة التثبيت.
  Future<String> _export(MTLocalizations l10n) async {
    final backup = ref.read(autoBackupProvider);
    if (!await backup.writeNow()) throw const BackupFormatException('write');
    return l10n.backupSuccess(backup.filePath);
  }

  Future<String> _exportKey(MTLocalizations l10n) async {
    final dir = Directory(liteMediaDir);
    await dir.create(recursive: true);
    final file = File('$liteMediaDir/$_keyFileName');
    await file.writeAsString(await _service.exportKeyFile(), flush: true);
    await Share.shareXFiles([XFile(file.path)]);
    return l10n.keyExported(file.path);
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

  Future<String> _import(MTLocalizations l10n) async {
    final contents = await _pickFileContents();
    if (contents == null) throw const BackupCancelledException();
    final result = await _service.importFromString(contents);
    await _refreshEverything();
    final formatName = switch (result.format) {
      BackupFormat.v2 => 'MTF1',
      BackupFormat.legacyLite => 'MTBACKUP1',
      BackupFormat.legacySuper => 'MTSBACKUP1',
    };
    return '${l10n.restoreSuccess} · $formatName · ${result.keysRestored}';
  }

  Future<String> _importKey(MTLocalizations l10n) async {
    final contents = await _pickFileContents();
    if (contents == null) throw const BackupCancelledException();
    final ok = await _service.importKeyFile(contents);
    if (!ok) throw const BackupFormatException('bad key file');
    return l10n.keyImported;
  }

  /// كل ما قد تكون النسخة غيّرته يُعاد تحميله (ر-8 خطوة 1).
  Future<void> _refreshEverything() async {
    await ref.read(settingsProvider.notifier).reloadFromStore();
    ref.invalidate(localMediaProvider);
    ref.invalidate(playlistsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;

    ListTile tile(IconData icon, String title, String subtitle,
            Future<String> Function(MTLocalizations) action) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: !_busy,
          leading: Icon(icon, color: p.ink2),
          title: Text(title),
          subtitle:
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          onTap: () => _run(action),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.pagePad, 0, MTSpace.pagePad, MTSpace.xxl),
        children: [
          MTSectionHeader(title: l10n.backupRestore),
          const SizedBox(height: MTSpace.sm),
          tile(Icons.backup_outlined, l10n.backupNow, l10n.backupNowSubtitle,
              _export),
          tile(Icons.restore_rounded, l10n.restoreData,
              l10n.restoreDataSubtitle, _import),
          const SizedBox(height: MTSpace.md),
          // م-31 (Lite): النسخة تُكتب وحدها — إخبار لا زر.
          Row(
            children: [
              Icon(Icons.autorenew_rounded, size: 16, color: p.ink3),
              const SizedBox(width: MTSpace.xs),
              Expanded(
                child: Text(l10n.autoBackupNote,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(color: p.ink3)),
              ),
            ],
          ),
          const SizedBox(height: MTSpace.xl),
          MTSectionHeader(title: l10n.exportKeyTitle),
          const SizedBox(height: MTSpace.sm),
          tile(Icons.key_outlined, l10n.exportBackupKey,
              l10n.exportBackupKeySubtitle, _exportKey),
          tile(Icons.vpn_key_outlined, l10n.importBackupKey,
              l10n.importBackupKeySubtitle, _importKey),
          const SizedBox(height: MTSpace.lg),
          Text(l10n.keySecurityWarning,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: p.ink3)),
          const SizedBox(height: MTSpace.md),
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
