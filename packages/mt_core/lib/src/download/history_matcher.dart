import '../api/metube_api.dart';
import '../models/history_item.dart';
import '../urls/url_kit.dart';

/// مُصالِح السجل: يربط المهمة **بعمليتها هي** على السيرفر، ويكنس ما
/// تتركه المهام الملغاة.
///
/// **سبب وجوده (العطل ح-3):** الاستطلاع كان يطابق أي عنصر في `/history`
/// بالرابط وحده، فيلتقط عناصر **قديمة**: عنصر فشل سابقاً بجدار كوكيز
/// يجعل إعادة المحاولة تفشل فوراً بينما التنزيل الجديد يكتمل يتيماً على
/// السيرفر، وعنصر بجودة 480 قديمة يُعلن نجاح طلب 1080 فيُسحب الملف
/// الخطأ. الحل: **لقطة قبل الإضافة** — كل عنصر بصمته كما كانت لحظة
/// الإضافة يُتجاهل حتى تتغير بصمته (اكتمال جديد، أو خطأ جديد).
class HistoryMatcher {
  const HistoryMatcher(this.api);

  final MeTubeApi api;

  /// بصمة العنصر: الرابط + الملف + الحالة + الخطأ. أي تقدم حقيقي
  /// للعملية الجديدة يغيّرها، وبقاء العنصر القديم كما هو لا يغيّرها.
  static String signature(HistoryItem item) =>
      '${item.canonicalUrl}|${item.filename}|${item.status.name}|${item.error}';

  /// بصمات ما يطابق [url] في السجل **قبل** الإضافة — فشل الجلب يعيد
  /// مجموعة فارغة (الإضافة التالية ستكشف انقطاع الشبكة بنفسها).
  Future<Set<String>> snapshot(String url) async {
    try {
      final history = await api.fetchHistory();
      return {
        for (final item in [...history.done, ...history.active])
          if (UrlKit.urlsMatch(item.canonicalUrl, url)) signature(item),
      };
    } on Object {
      return const <String>{};
    }
  }

  /// كنس يتيم السيرفر بعد إلغاء المستخدم (العطل ع-7).
  ///
  /// الإلغاء أثناء الإضافة/الاستطلاع كان يوقف المهمة **محلياً فقط**:
  /// السيرفر يواصل التنزيل ويودعه في `done` بلا أي مسار في التطبيق
  /// لإزالته — واليتيم يسمّم إعادة المحاولة لاحقاً. هنا نحذف ما ظهر
  /// **بعد** اللقطة حصراً، فلا نمسّ عنصراً كان موجوداً قبل مهمتنا.
  Future<void> deleteOrphan(String url, Set<String> before) async {
    try {
      final history = await api.fetchHistory();
      for (final item in history.active) {
        if (!UrlKit.urlsMatch(item.canonicalUrl, url)) continue;
        if (before.contains(signature(item))) continue;
        await api.delete([item.canonicalUrl], where: 'queue');
        return;
      }
      for (final item in history.done) {
        if (!UrlKit.urlsMatch(item.canonicalUrl, url)) continue;
        if (before.contains(signature(item))) continue;
        await api.delete([item.canonicalUrl]);
        return;
      }
    } on Object {
      // كنس أفضل-جهد: فشله لا يعني شيئاً للمستخدم الذي ألغى بالفعل.
    }
  }
}
