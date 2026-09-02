/// أنواع أخطاء مصنفة ترميها النواة — التطبيق يحوّلها لنص مترجم عند العرض
/// (`02-TRD.md` §3.3: لا نصوص واجهة من النواة).
sealed class MTApiException implements Exception {
  const MTApiException([this.detail]);

  /// تفصيل تقني اختياري (رسالة السيرفر الخام) — للسجلات لا للعرض المباشر.
  final String? detail;

  /// هل تُعاد المحاولة تلقائياً عند عودة الشبكة؟ (م-43)
  ///
  /// **نعم لعطل الطريق، لا لرفض الوجهة.** الانقطاع ومهلة الاستطلاع
  /// عارضان تُصلحهما الشبكة نفسها. أما الاعتماد الخاطئ أو حظر المنصة أو
  /// خطأ السيرفر الصريح فقرار من الطرف الآخر: إعادته بلا تغيير تفشل
  /// مرة أخرى، وتُغرق السيرفر بطلبات محكوم عليها.
  bool get isRetryable =>
      this is NetworkException || this is PollTimeoutException;

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

/// أُلغيت المهمة بطلب المستخدم — ليست خطأً يُعرض.
final class CancelledException extends MTApiException {
  const CancelledException([super.detail]);
}

/// انقضت مهلة استطلاع `/history` (120×5s) دون اكتمال العنصر.
final class PollTimeoutException extends MTApiException {
  const PollTimeoutException([super.detail]);
}
