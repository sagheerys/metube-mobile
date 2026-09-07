import 'url_keyed_index.dart';

/// **ذاكرة إخفاقات السبر** (عطل المصغرات 2026-09-07): canonicalUrl →
/// لحظة آخر إخفاق.
///
/// بدونها يُعاد سبر العنصر المستحيل **عند كل إقلاع**: سجلٌّ في المكتبة
/// لملف حُذف من قرص السيرفر كان يستهلك أكثر من ٨٠ ثانية في كل جلسة
/// (منصة أندرويد تعيد المحاولة عشراً بمهلة ٨s) ويُجمّد الطابور خلفه —
/// فبقيت مكتبة المالك بلا مصغرات إلا ليوتيوب (وهي مشتقّة لا مسبورة).
final class ProbeFailureIndex extends UrlKeyedIndex<DateTime> {
  ProbeFailureIndex({required super.store, required super.mutex})
      : super(prefsKey: 'probe_failures');

  /// مهلة النسيان: الملف قد يعود (رُفع من جديد، أو عاد السيرفر).
  static const retryAfter = Duration(days: 1);

  @override
  DateTime? decodeValue(dynamic raw) {
    final ms = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  dynamic encodeValue(DateTime value) => value.millisecondsSinceEpoch;

  /// هل يُتخطّى هذا العنصر الآن؟ (أخفق قريباً)
  bool isCoolingDown(Map<String, DateTime> failures, String canonicalUrl,
      {DateTime? now}) {
    final at = failures[canonicalUrl];
    if (at == null) return false;
    return (now ?? DateTime.now()).difference(at) < retryAfter;
  }
}
