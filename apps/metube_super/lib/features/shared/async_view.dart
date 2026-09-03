import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **تحويل حالة غير متزامنة مع الحفاظ على القيمة السابقة.**
///
/// بلاغ المالك 2026-09-03: «لا يزال هناك وميض في المكتبة أثناء
/// التحميل». السبب كان `AsyncValue.whenData`: هي توزّع على **نوع**
/// الحالة لا على وجود قيمة، فتعيد عند `AsyncLoading` نسخة **جديدة
/// فارغة** — أي أنها تتلف ما يحتفظ به Riverpod من بيانات سابقة، فلا
/// يصل الشاشةَ شيءٌ لتفضّله على الدوّارة.
///
/// الأثر مقيس بتسجيل شاشة على المحاكي (Super): إبطالٌ كل ثانيتين
/// وجلبُ سجلٍّ يستغرق قريباً منها ⇒ **دوّارة ١٣ ثانية متصلة** محل
/// المكتبة أثناء تحميل واحد، ثم عودتها لحظة توقف الاستطلاع.
///
/// القاعدة: **قيمة موجودة ⇒ تُبنى وتُعرض · وإلا الخطأ · وإلا التحميل.**
AsyncValue<R> asyncViewOf<T, R>(
  AsyncValue<T> source,
  R Function(T value) build,
) {
  final value = source.valueOrNull;
  if (value != null) return AsyncData(build(value));
  return source.hasError
      ? AsyncError<R>(source.error!, source.stackTrace ?? StackTrace.empty)
      : const AsyncLoading();
}
