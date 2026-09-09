import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import '../library/library_actions.dart' show superMediaDir;

/// The backups folder, inside the app's media folder (§5.3).
const superBackupDir = '$superMediaDir/backups';

/// The backup name prefix, **new on purpose** (requested 2026-09-04): the
/// old name `metube_super_backup.json` is owned by an earlier install, and
/// Android 11+ refuses to let this one write over it (`errno 13`).
const superBackupPrefix = 'metube_super';

final backupRotationProvider = Provider(
  (ref) => BackupRotation(directory: superBackupDir, prefix: superBackupPrefix),
);

final autoBackupProvider = Provider(
  (ref) => AutoBackup(
    service: ref.watch(backupServiceProvider),
    rotation: ref.watch(backupRotationProvider),
    logger: ref.watch(loggerProvider),
  ),
);

/// Automatic backup for Super (added 2026-09-04): a copy after every data
/// change.
///
/// Lite alone used to back up automatically, while Super's data, tags and
/// playlists over hundreds of items, is more valuable and cannot be
/// reloaded from anywhere.
///
/// **The trap that is gone** (decision 2026-09-04): the copy used to be
/// encrypted with a key living in secure storage, so uninstalling or
/// clearing data wiped it and left the backup on disk **undecryptable**
/// unless the user had exported the key, which nobody does. The file is
/// now plain text with no secret in it, so it always survives.
///
/// Rotation, atomic writing and duplicate prevention live in
/// [BackupRotation]; only the time-based batching lives here.
class AutoBackup {
  AutoBackup({
    required this.service,
    required this.rotation,
    required this.logger,
    this.debounce = const Duration(seconds: 3),
  });

  final BackupService service;
  final BackupRotation rotation;
  final MTLogger logger;

  /// Batches consecutive changes into one write: a download batch becomes
  /// one file.
  final Duration debounce;

  Timer? _pending;
  bool _writing = false;
  bool _pendingRewrite = false;

  /// Called after any data change; the caller does not actually await it.
  Future<void> requestBackup() async {
    _pending?.cancel();
    _pending = Timer(debounce, () => unawaited(writeNow()));
  }

  /// An immediate write. Returns the file written, or `null` when nothing
  /// changed since the last copy, or the write failed and the reason is in
  /// the log.
  Future<BackupFile?> writeNow() async {
    // **A request during an in-flight write is repeated rather than dropped
    // (fix م-5):** the newest change used to be lost until another change
    // happened, and one might never happen.
    if (_writing) {
      _pendingRewrite = true;
      return null;
    }
    _writing = true;
    try {
      final written = await rotation.write(await service.exportToString());
      if (written != null) {
        await logger.log('auto backup ${written.name}', tag: 'backup');
      }
      return written;
    } catch (e) {
      await logger.error('auto backup failed', cause: e, tag: 'backup');
      return null;
    } finally {
      _writing = false;
      if (_pendingRewrite) {
        _pendingRewrite = false;
        unawaited(requestBackup());
      }
    }
  }

  Future<List<BackupFile>> list() => rotation.list();
  Future<BackupFile?> latest() => rotation.latest();

  /// Restores one specific copy.
  Future<ImportResult> restore(BackupFile file) async =>
      service.importFromString(await rotation.read(file));
}
