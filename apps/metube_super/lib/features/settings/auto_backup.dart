import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import '../library/library_actions.dart' show superMediaDir;

/// مجلد النسخ داخل مجلد وسائط التطبيق (§5.3).
const superBackupDir = '$superMediaDir/backups';

/// بادئة أسماء النسخ — **جديدة عمداً** (طلب المالك 2026-09-04): الاسم
/// القديم `metube_super_backup.json` يملكه تثبيت سابق، وأندرويد 11+
/// يمنع الكتابة فوقه (`errno 13`).
const superBackupPrefix = 'metube_super';

final backupRotationProvider = Provider((ref) => BackupRotation(
      directory: superBackupDir,
      prefix: superBackupPrefix,
    ));

final autoBackupProvider = Provider((ref) => AutoBackup(
      service: ref.watch(backupServiceProvider),
      rotation: ref.watch(backupRotationProvider),
      logger: ref.watch(loggerProvider),
    ));

/// م-31 (سوبر — أُضيف 2026-09-04): نسخة تلقائية بعد كل تغيير بيانات.
///
/// كان لايت وحده ينسخ تلقائياً، بينما بيانات سوبر (الوسوم والقوائم على
/// مئات العناصر) أثمن ولا يمكن إعادة تحميلها.
///
/// **الفخ الذي زال** (قرار المالك 2026-09-04): كانت النسخة مشفّرة
/// بمفتاح يعيش في التخزين الآمن، فإلغاء التثبيت أو «مسح البيانات» يمحوه
/// وتبقى النسخة على القرص **غير قابلة للفك** ما لم يكن المستخدم صدّر
/// المفتاح — وهو ما لا يفعله أحد. الملف الآن نصّي بلا سرّ، فينجو دائماً.
///
/// الدوران والكتابة الذرّية ومنع التكرار في [BackupRotation]؛ هنا
/// التجميع الزمني وحده.
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

  /// تجميع التغييرات المتتابعة في كتابة واحدة (دفعة تحميل = ملف واحد).
  final Duration debounce;

  Timer? _pending;
  bool _writing = false;
  bool _pendingRewrite = false;

  /// يُستدعى بعد أي تغيير بيانات — لا ينتظره المستدعي فعلياً.
  Future<void> requestBackup() async {
    _pending?.cancel();
    _pending = Timer(debounce, () => unawaited(writeNow()));
  }

  /// كتابة فورية. تعيد الملف المكتوب، أو `null` إن لم يتغير شيء منذ
  /// آخر نسخة (أو فشلت الكتابة — والسبب في السجل).
  Future<BackupFile?> writeNow() async {
    // **الطلب أثناء كتابة جارية يُعاد لا يُسقط (إصلاح م-5):** التغيير
    // الأحدث كان يضيع حتى يقع تغيير تالٍ — وربما لا يقع أبداً.
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

  /// استعادة نسخة بعينها.
  Future<ImportResult> restore(BackupFile file) async =>
      service.importFromString(await rotation.read(file));
}
