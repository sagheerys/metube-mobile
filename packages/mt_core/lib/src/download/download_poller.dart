import 'dart:async';

import '../api/api_exceptions.dart';
import '../api/metube_api.dart';
import '../models/history_item.dart';
import '../urls/url_kit.dart';
import 'history_matcher.dart';

/// استطلاع `/history` حتى يكتمل عنصر **هذه** المهمة (§2.3).
///
/// فُصل عن `download_engine.dart` لحدّ الأسطر (القاعدة 4) — وهو أيضاً
/// موضع القاعدة الحاسمة في ح-3: **بصمات ما قبل الإضافة تُتجاهل**، فلا
/// يُنسب للمهمة عنصرٌ قديم (خطأ سابق يسمّم إعادة المحاولة، أو ملف بجودة
/// قديمة يُعلن نجاح طلب جودة أعلى).
class DownloadPoller {
  const DownloadPoller({
    required this.api,
    required this.pollInterval,
    required this.maxAttempts,
  });

  final MeTubeApi api;
  final Duration pollInterval;
  final int maxAttempts;

  /// [checkAborted] يرمي عند الإلغاء أو تصريف المحرك؛ [onProgress] يبثّ
  /// تقدم السيرفر. يعيد العنصر المكتمل أو يرمي مصنفاً.
  Future<HistoryItem> pollUntilDone({
    required String url,
    required Set<String> before,
    required void Function() checkAborted,
    required void Function(double progress) onProgress,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      checkAborted();
      final history = await api.fetchHistory();

      for (final item in [...history.done, ...history.active]) {
        if (!UrlKit.urlsMatch(item.canonicalUrl, url)) continue;
        if (before.contains(HistoryMatcher.signature(item))) continue;
        if (item.hasError) {
          final detail = item.error ?? item.rawStatus;
          throw item.isPlatformBlocked
              ? PlatformBlockedException(detail)
              : ServerErrorException(detail);
        }
        // filename غائب ⇒ ننتظر (لا يُخلَّق من العنوان أبداً — فخ §6.3).
        if (item.isCompleted && item.filename != null) return item;
        if (item.progress != null) onProgress(item.progress!);
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(pollInterval);
      }
    }
    throw const PollTimeoutException();
  }
}
