import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import '../downloads_library/local_item.dart';

/// اسم ملف النسخة التلقائية في مجلد Lite (§5.3) — نفس اسم Lite القديم.
const liteBackupFileName = 'metube_lite_backup.json';

final autoBackupProvider = Provider((ref) => AutoBackup(
      service: ref.watch(backupServiceProvider),
      logger: ref.watch(loggerProvider),
    ));

/// م-31 (Lite): نسخة تلقائية بعد كل تغيير بيانات + استعادة بعد إعادة
/// التثبيت.
///
/// **الفخ الموروث من Lite القديم:** مفتاح AES يعيش في التخزين الآمن،
/// وإلغاء التثبيت أو «مسح البيانات» يمحوه — فيبقى ملف النسخة على القرص
/// **غير قابل للفك** ما لم يكن المستخدم صدّر المفتاح. لذلك الاستعادة
/// التلقائية تميّز هذه الحالة وتعرضها صراحةً بدل «فشل غامض».
class AutoBackup {
  AutoBackup({
    required this.service,
    required this.logger,
    this.directory = liteMediaDir,
    this.debounce = const Duration(seconds: 3),
  });

  final BackupService service;
  final MTLogger logger;
  final String directory;

  /// تجميع التغييرات المتتابعة في كتابة واحدة (دفعة تحميل = ملف واحد).
  final Duration debounce;

  Timer? _pending;
  bool _writing = false;

  String get filePath => '$directory/$liteBackupFileName';

  /// يُستدعى بعد أي تغيير بيانات — لا ينتظره المستدعي فعلياً.
  Future<void> requestBackup() async {
    _pending?.cancel();
    _pending = Timer(debounce, () => unawaited(writeNow()));
  }

  /// كتابة فورية (تُستعمل أيضاً في الإغلاق والاختبار).
  Future<bool> writeNow() async {
    if (_writing) return false;
    _writing = true;
    try {
      final contents = await service.exportToString();
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(contents, flush: true);
      await logger.log('auto backup written', tag: 'backup');
      return true;
    } catch (e) {
      await logger.error('auto backup failed', cause: e, tag: 'backup');
      return false;
    } finally {
      _writing = false;
    }
  }

  Future<bool> exists() => File(filePath).exists();

  /// حالة النسخة التلقائية الموجودة على القرص.
  Future<AutoRestoreState> inspect() async {
    final file = File(filePath);
    if (!await file.exists()) return AutoRestoreState.none;
    try {
      final header = BackupCrypto.headerOf(await file.readAsString());
      return header == null
          ? AutoRestoreState.unreadable
          : AutoRestoreState.available;
    } catch (_) {
      // ملف موجود لكن لا يمكن قراءته (أذونات/تلف).
      return AutoRestoreState.unreadable;
    }
  }

  /// استعادة النسخة التلقائية. يرمي [BackupKeyMismatchException] حين
  /// يكون المفتاح قد ضاع مع إعادة التثبيت — وهي الحالة «اليتيمة».
  Future<ImportResult> restore() async =>
      service.importFromString(await File(filePath).readAsString());

  Future<void> deleteFile() async {
    final file = File(filePath);
    if (await file.exists()) await file.delete();
  }
}

enum AutoRestoreState { none, available, unreadable }
