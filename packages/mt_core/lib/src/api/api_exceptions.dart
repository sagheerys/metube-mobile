/// أنواع أخطاء مصنفة ترميها النواة — التطبيق يحوّلها لنص مترجم عند العرض
/// (`02-TRD.md` §3.3: لا نصوص واجهة من النواة).
sealed class MTApiException implements Exception {
  const MTApiException([this.detail]);

  /// تفصيل تقني اختياري (رسالة السيرفر الخام) — للسجلات لا للعرض المباشر.
  final String? detail;

  @override
  String toString() =>
      detail == null ? runtimeType.toString() : '$runtimeType: $detail';
}

/// 401 — اعتمادات Basic Auth خاطئة.
final class AuthFailureException extends MTApiException {
  const AuthFailureException([super.detail]);
}

/// استجابة 200 لكنها ليست JSON بحقلي `done` و`queue` (غالباً HTML).
final class NotMeTubeServerException extends MTApiException {
  const NotMeTubeServerException([super.detail]);
}

/// 404 — العنوان يستجيب لكن لا يوجد MeTube API عليه.
final class NoApiException extends MTApiException {
  const NoApiException([super.detail]);
}

/// تعذر الوصول: انقطاع، مهلة، DNS، شهادة...
final class NetworkException extends MTApiException {
  const NetworkException([super.detail]);
}

/// السيرفر ردّ بخطأ صريح (حقل `error`/`msg` أو حالة HTTP خطأ).
final class ServerErrorException extends MTApiException {
  const ServerErrorException([super.detail]);
}

/// خطأ سيرفر نصّه يدل على حظر المنصة (login / sign in / cookie / bot)
/// ⇒ واجهة المستخدم تقترح تحديث الكوكيز.
final class PlatformBlockedException extends ServerErrorException {
  const PlatformBlockedException([super.detail]);
}

/// اسم ملف من السيرفر فشل في حارس أمان المسار (`..` أو `/` أو `\` أو فارغ).
final class UnsafeFilenameException extends MTApiException {
  const UnsafeFilenameException([super.detail]);
}
