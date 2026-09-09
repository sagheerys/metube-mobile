import '../constants/mt_constants.dart';
import '../resolvers/http_fetch.dart';
import 'app_version.dart';
import 'update_release.dart';

/// فحص التحديثات من GitHub Releases (م-66).
///
/// **معزول عن `MeTubeApiClient` تماماً** (القاعدة 1): يستعمل
/// [HttpGetString] نفسه الذي تستعمله محلّلات المنصات، فلا تتسرّب ترويسة
/// اعتماد سيرفر المالك إلى GitHub، ولا يعرف GitHub شيئاً عن السيرفر.
///
/// **فاشل-آمن بالكامل**: كل مسار خطأ يعيد `null`. لا شبكة ولا مستودع
/// خاص ولا JSON غريب يُظهر للمستخدم رسالة خطأ في فحص تلقائي — التحديث
/// خدمة، لا واجب.
class UpdateChecker {
  UpdateChecker({
    required this.fetch,
    required this.assetMarker,
    this.repo = MTConstants.updateRepo,
  });

  final HttpGetString fetch;

  /// جزء من اسم ملف APK يميّز هذا التطبيق: `super` أو `lite`.
  final String assetMarker;

  /// `owner/name` — نقطة التبديل الوحيدة لو انفصلت الإصدارات في مستودع
  /// عام مستقل عن مستودع الكود.
  final String repo;

  Uri get latestUri =>
      Uri.parse('https://api.github.com/repos/$repo/releases/latest');

  /// يعيد الإصدار المتاح إن كان **أحدث فعلاً** من [currentVersion]،
  /// وإلا `null`.
  ///
  /// [skippedVersion] هو ما اختار المستخدم تخطّيه؛ يُكتم ما دام هو
  /// الأحدث، ويعود الظهور تلقائياً عند صدور ما بعده.
  Future<UpdateRelease?> check({
    required String currentVersion,
    String? skippedVersion,
  }) async {
    final current = AppVersion.tryParse(currentVersion);
    // **إصدار محلي غير مقروء = لا فحص**: بلا مرجع للمقارنة قد نعرض
    // «تحديثاً» إلى نسخة أقدم مما على الجهاز.
    if (current == null) return null;

    final UpdateRelease? release;
    try {
      final body = await fetch(latestUri);
      release = UpdateRelease.tryParse(body, assetMarker: assetMarker);
    } catch (_) {
      return null;
    }
    if (release == null) return null;
    if (release.version <= current) return null;

    final skipped = AppVersion.tryParse(skippedVersion);
    if (skipped != null && release.version <= skipped) return null;
    return release;
  }

  /// هل حان الفحص التلقائي؟ يمنع طلباً عند كل إقلاع.
  ///
  /// `null` في [lastCheck] تعني «لم يُفحص قط» — فيُفحص فوراً.
  static bool isDue(
    DateTime? lastCheck,
    DateTime now, {
    Duration interval = MTConstants.updateCheckInterval,
  }) {
    if (lastCheck == null) return true;
    // **ساعة الجهاز قد ترجع للوراء** (تغيير المنطقة، مزامنة NTP):
    // فحصٌ «في المستقبل» لا يجوز أن يجمّد الميزة إلى الأبد.
    if (lastCheck.isAfter(now)) return true;
    return now.difference(lastCheck) >= interval;
  }
}
