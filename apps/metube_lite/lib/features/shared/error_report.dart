import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import 'error_text.dart';

/// **كل خطأ يُعرض يُكتب أيضاً** (طلب المالك 2026-09-06).
///
/// كان السجل التشخيصي سجلَّ تحميلات لا سجلَّ أخطاء: أربعون موضع رسالة
/// خطأ في هذا التطبيق ولا واحد منها يصل السجل — حتى حادثة رفض الاعتماد
/// التي أطاحت بالمكتبة كاملةً (2026-09-05) لم تترك فيه سطراً.
///
/// **النصّ للمستخدم مترجم، وللسجل تقني**: السجل يُقرأ بعد أسبوع ومن
/// جهاز آخر، فترجمته تُفقده الدلالة (`AuthFailureException: HTTP 401`
/// أنفع من «اسم المستخدم أو كلمة المرور خاطئة»).
void showErrorSnack(
  BuildContext context,
  WidgetRef ref,
  Object error, {
  String tag = 'ui',
}) {
  unawaited(logError(ref.read(loggerProvider), error, tag: tag));
  showMTSnack(context, errorText(context.mtl, error), type: MTSnackType.error);
}

/// **يعيد المستقبل ولا يبتلعه**: النداء من الواجهة `unawaited` كي لا
/// تنتظر الشاشةُ القرصَ، لكن الاختبار يحتاج انتظاراً حاسماً لا استطلاعاً
/// يتقلب مع سرعة القرص.
Future<void> logError(MTLogger logger, Object error, {String tag = 'ui'}) =>
    logger.error(error.toString(), tag: tag);

/// **توقيع آخر خطأ لكل مصدر متكرر.** الاستطلاع الحي كل ثانيتين يعيد
/// نفس العطل ثلاثين مرة في الدقيقة، والسجل حلقي بألف سطر: بلا هذا
/// المرشّح يمسح عطلٌ واحدٌ تاريخَ التطبيق كله في نصف ساعة.
final _lastSignature = <String, String>{};

/// يسجّل الخطأ **إن تغيّر** عمّا سُجّل آخر مرة لهذا المصدر.
Future<void> logErrorOnce(
  MTLogger logger,
  String source,
  Object error, {
  String tag = 'network',
}) {
  final signature = error.toString();
  if (_lastSignature[source] == signature) return Future<void>.value();
  _lastSignature[source] = signature;
  return logger.error('$source: $signature', tag: tag);
}

/// يُنادى عند نجاح المصدر — فتكرار العطل بعد تعافٍ حدثٌ جديد يستحق سطراً.
void clearErrorSignature(String source) => _lastSignature.remove(source);
