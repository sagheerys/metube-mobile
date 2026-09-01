import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;

import '../api/api_exceptions.dart';
import '../api/metube_api.dart';
import '../constants/mt_constants.dart';

/// السحب بإعادة محاولة (§2.4): 3 محاولات بتراجع 3s/6s (انقطاعات
/// Cloudflare)، **حذف الملف الجزئي قبل كل محاولة** وعند الإلغاء/الفشل.
class Transfer {
  Transfer({
    required this.api,
    this.retries = MTConstants.pullRetries,
    this.backoff = MTConstants.pullRetryBackoff,
  });

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
    for (var attempt = 0; attempt < retries; attempt++) {
      await _deletePartial(savePath);
      try {
        await api.downloadTo(
          serverFilename,
          savePath,
          cancelToken: cancelToken,
          onProgress: (received, total) {
            if (onProgress != null && total > 0) {
              onProgress(received / total);
            }
          },
        );
        return;
      } on CancelledException {
        await _deletePartial(savePath);
        rethrow;
      } on MTApiException {
        await _deletePartial(savePath);
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
