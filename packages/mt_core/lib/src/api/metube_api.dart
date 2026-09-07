import 'package:dio/dio.dart' show CancelToken;

import '../models/history_response.dart';
import '../models/quality.dart';

/// عقد سيرفر MeTube المجرد — [MeTubeApiClient] هو التنفيذ الوحيد في
/// الإنتاج (القاعدة 1)، والواجهة تتيح محاكاة السيرفر في اختبارات المحرك.
abstract interface class MeTubeApi {
  Future<void> testConnection({Duration? timeout});
  Future<HistoryResponse> fetchHistory();
  /// [compatibleVideo] يطلب **H.264/AAC في mp4** بدل ترك الخادم يختار
  /// (§2.2) — لا يُرسل مع `audio` أبداً. انظر التنفيذ للسبب المقيس.
  Future<void> add(String url, Quality quality, {bool compatibleVideo});
  Future<void> delete(List<String> canonicalUrls, {String where});
  String downloadUrl(String serverFilename);

  /// **هل الملف موجود فعلاً على السيرفر الآن؟** (بايت واحد بمهلة قصيرة)
  ///
  /// سجلٌّ في `/history` لا يعني ملفاً على القرص: عنصر واحد ميت عند
  /// المالك كان يكفي لتجميد سبر المصغرات كله (2026-09-07).
  Future<bool> fileExists(String serverFilename, {Duration? timeout});

  /// سحب ملف إلى مسار محلي بتقدم حي وإلغاء — تنفيذ واحد بلا إعادة
  /// محاولة؛ منطق الإعادة في `Transfer`.
  Future<void> downloadTo(
    String serverFilename,
    String savePath, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });

  Map<String, String> get streamingHeaders;
}
