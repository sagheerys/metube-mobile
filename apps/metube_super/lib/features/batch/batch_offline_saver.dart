import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import '../library/library_actions.dart';

/// **حفظ الدفعة على الجهاز** (طلب المالك 2026-09-03: «ألبوم ساوندكلاود
/// لا يُحمَّل على الجهاز وإنما على السيرفر»).
///
/// Super يضيف للسيرفر ولا يسحب (ر-2) — والسحب فيه فعلٌ مستقل اسمه
/// «إتاحة دون اتصال» (م-17). هذا الصنف **لا يخترق تلك القاعدة**: يطبّق
/// م-17 نفسه على كل عضو دفعة اكتمل، حين يطلب المالك ذلك صراحةً بمفتاح
/// شاشة الدفعي. الأصل يبقى على السيرفر كما هي القاعدة.
///
/// **متسلسل لا متوازٍ:** ألبوم من 400 مقطع يعني 400 تنزيل — بدؤها معاً
/// يخنق الشبكة ويُفشل بعضها بمهلة انتهاء.
class BatchOfflineSaver {
  BatchOfflineSaver({required this.pull, this.onError});

  /// السحب الفعلي — يُحقن ليبقى الصنف قابلاً للاختبار بلا شبكة.
  final Future<void> Function(DownloadTask task) pull;
  final void Function(Object error)? onError;

  /// معرّفات مهام تنتظر السحب بعد اكتمالها على السيرفر.
  final Set<String> _wanted = {};

  /// سلسلة السحب — كل عنصر ينتظر سابقه.
  Future<void> _chain = Future<void>.value();

  /// للاختبار: الانتظار حتى يفرغ الطابور.
  Future<void> get idle => _chain;

  int get pendingCount => _wanted.length;

  /// تُنادى عند الإدراج: هذه الدفعة يريدها المالك على الجهاز.
  void want(Iterable<String> taskIds) => _wanted.addAll(taskIds);

  /// عضو سقط (فشل أو أُلغي) لا يُنتظر سحبه — وإلا تسرّبت المعرّفات.
  void forget(String taskId) => _wanted.remove(taskId);

  /// اكتمل عضو ⇒ يُسحب بدوره في الطابور.
  void onFinished(DownloadTask task) {
    if (!_wanted.remove(task.id)) return;
    if ((task.canonicalUrl ?? '').isEmpty) return;
    _chain = _chain.then((_) => _guarded(task));
  }

  /// **فشل السحب لا يُسقط بقية الألبوم**: العنصر يبقى على السيرفر
  /// ويستطيع المالك سحبه لاحقاً بنقرة «إتاحة دون اتصال».
  Future<void> _guarded(DownloadTask task) async {
    try {
      await pull(task);
    } on Object catch (error) {
      onError?.call(error);
    }
  }
}

final batchOfflineSaverProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  return BatchOfflineSaver(
    pull: (task) async {
      await ref.read(libraryActionsProvider).pullToDevice(
            canonicalUrl: task.canonicalUrl!,
            serverFilename: task.serverFilename,
            title: task.title ?? task.canonicalUrl!,
            thumbnail: task.thumbnail,
          );
      unawaited(logger.log('batch saved to device ${task.title ?? ''}',
          tag: 'download'));
    },
    onError: (error) => unawaited(
        logger.error('batch save to device failed: $error', tag: 'download')),
  );
});
