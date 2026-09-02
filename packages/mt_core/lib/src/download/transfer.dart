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

  /// يعيد **المسار النهائي فعلاً** — قد يختلف عن [savePath] إن كان
  /// مشغولاً (خ-3)، والمنادي يفهرس بما يعود لا بما طلب.
  Future<String> pull({
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
        final target = await _freeTarget(savePath);
        await File(partPath).rename(target);
        return target;
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
    throw const NetworkException('pull exhausted');
  }

  /// **هدف غير مشغول (إصلاح خ-3).** اسم الملف المحلي يحمل طابع
  /// `HHmmss` بلا تاريخ (§2.4)، فعنوانان متطابقان في الثانية نفسها —
  /// وارد في الدفعات الصوتية — أو في نفس الوقت من يومين، كانا يجعلان
  /// `rename` **يدهس الملف الأقدم بصمت**. الصيغة تبقى كما وثّقها العقد،
  /// والتصادم النادر يُحلّ بلاحقة رقمية.
  static Future<String> _freeTarget(String savePath) async {
    if (!await File(savePath).exists()) return savePath;
    final dot = savePath.lastIndexOf('.');
    final stem = dot > 0 ? savePath.substring(0, dot) : savePath;
    final ext = dot > 0 ? savePath.substring(dot) : '';
    for (var i = 2; i < 100; i++) {
      final candidate = '$stem($i)$ext';
      if (!await File(candidate).exists()) return candidate;
    }
    return savePath;
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
