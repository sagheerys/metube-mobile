import 'package:dio/dio.dart' show CancelToken;

import '../models/history_response.dart';
import '../models/quality.dart';

/// عقد سيرفر MeTube المجرد — [MeTubeApiClient] هو التنفيذ الوحيد في
/// الإنتاج (القاعدة 1)، والواجهة تتيح محاكاة السيرفر في اختبارات المحرك.
abstract interface class MeTubeApi {
  Future<void> testConnection({Duration? timeout});
  Future<HistoryResponse> fetchHistory();
  Future<void> add(String url, Quality quality);
  Future<void> delete(List<String> canonicalUrls, {String where});
  String downloadUrl(String serverFilename);

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
