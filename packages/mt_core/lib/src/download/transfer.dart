import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;

import '../api/api_exceptions.dart';
import '../api/metube_api.dart';
import '../constants/mt_constants.dart';

/// السحب بإعادة محاولة (§2.4): 3 محاولات بتراجع 3s/6s (انقطاعات
/// Cloudflare)، **حذف الملف الجزئي قبل كل محاولة** وعند الإلغاء/الفشل.
///
/// **الكتابة إلى `<savePath>.part` ثم إعادة تسمية** (بلاغ المالك
/// 2026-09-02): Dio يكتب تدريجياً في الملف النهائي، ومكتبة Lite تُبنى
/// من **مسح المجلد** — فكان المقطع يظهر في المكتبة نصف محمّل، ويرتجف
/// حجمه مع كل تحديث. اللاحقة `.part` ليست امتداد وسائط فيتخطاها المسح.
class Transfer {
  Transfer({
    required this.api,
    this.retries = MTConstants.pullRetries,
    this.backoff = MTConstants.pullRetryBackoff,
  });

  /// لاحقة الملف الجزئي — **يجب ألا تكون امتداد وسائط** كي يتخطاها مسح
  /// المكتبة (`isMediaFile`).
  static const partSuffix = '.part';

  final MeTubeApi api;
  final int retries;

  /// فترات الانتظار بين المحاولات — تُصفَّر في الاختبارات.
  final List<Duration> backoff;

  Future<void> pull({
    required String serverFilename,
    required String savePath,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final partPath = '$savePath$partSuffix';
    for (var attempt = 0; attempt < retries; attempt++) {
      await _deletePartial(partPath);
      try {
        await api.downloadTo(
          serverFilename,
          partPath,
          cancelToken: cancelToken,
          onProgress: (received, total) {
            if (onProgress != null && total > 0) {
              onProgress(received / total);
            }
          },
        );
        // النقلة الذرية: من هنا فقط يراه مسح المجلد.
        await File(partPath).rename(savePath);
        return;
      } on CancelledException {
        await _deletePartial(partPath);
        rethrow;
      } on MTApiException {
        await _deletePartial(partPath);
        final isLastAttempt = attempt == retries - 1;
        if (isLastAttempt) rethrow;
        if (attempt < backoff.length) {
          await Future<void>.delayed(backoff[attempt]);
        }
        if (cancelToken?.isCancelled ?? false) {
          throw const CancelledException();
        }
      }
    }
  }

  Future<void> _deletePartial(String savePath) async {
    try {
      final file = File(savePath);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // ملف مقفل مؤقتاً — المحاولة التالية ستكتب فوقه.
    }
  }
}
