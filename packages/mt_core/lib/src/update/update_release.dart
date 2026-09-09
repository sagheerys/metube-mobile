import 'dart:convert';

import 'app_version.dart';

/// إصدار منشور على GitHub، مقروءاً من `releases/latest`.
class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.tag,
    required this.apkUrl,
    required this.apkSize,
    this.notes = '',
    this.pageUrl = '',
    this.publishedAt,
  });

  final AppVersion version;
  final String tag;

  /// رابط تنزيل ملف APK المطابق لهذا التطبيق (Lite أو Super).
  final String apkUrl;

  /// حجم الملف بالبايت — `0` إن لم يصرّح به السيرفر.
  final int apkSize;

  /// ملاحظات الإصدار (Markdown خام كما كتبها المطوّر).
  final String notes;

  /// صفحة الإصدار — بديل يدوي حين يتعذّر التثبيت داخل التطبيق.
  final String pageUrl;

  final DateTime? publishedAt;

  /// الحجم بالميغابايت لعرضه للمستخدم، أو `null` إن كان مجهولاً.
  double? get sizeMb => apkSize <= 0 ? null : apkSize / (1024 * 1024);

  /// يقرأ ردّ GitHub ويختار الأصل المطابق لـ [assetMarker].
  ///
  /// يعيد `null` — لا يرمي — عند أي شذوذ: مسودّة، تجريبي، إصدار بلا
  /// APK لهذا التطبيق، أو JSON غير متوقّع. **فحص التحديث لا يزعج
  /// المستخدم بخطأ أبداً** (§ر-5: الميزة الجديدة لا تكسر ما يعمل).
  static UpdateRelease? tryParse(String body, {required String assetMarker}) {
    Object? decoded;
    try {
      decoded = json.decode(body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    // **المسودّات والتجريبية تُرفض هنا أيضاً** رغم أن `releases/latest`
    // يستبعدها: نفس المحلّل يخدم `releases` الكاملة لو تغيّرت النقطة.
    if (decoded['draft'] == true || decoded['prerelease'] == true) return null;

    final tag = decoded['tag_name'];
    if (tag is! String) return null;
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;

    final assets = decoded['assets'];
    if (assets is! List) return null;
    final marker = assetMarker.toLowerCase();
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is! String || url is! String) continue;
      final lower = name.toLowerCase();
      // **المطابقة بالعلامة وبالامتداد معاً**: الإصدار الواحد يحمل
      // ملفَّي التطبيقين، فبلا العلامة يثبّت مالك Lite نسخة Super.
      if (!lower.endsWith('.apk') || !lower.contains(marker)) continue;
      final size = asset['size'];
      return UpdateRelease(
        version: version,
        tag: tag,
        apkUrl: url,
        apkSize: size is int ? size : 0,
        notes: decoded['body'] is String ? decoded['body'] as String : '',
        pageUrl: decoded['html_url'] is String
            ? decoded['html_url'] as String
            : '',
        publishedAt: decoded['published_at'] is String
            ? DateTime.tryParse(decoded['published_at'] as String)
            : null,
      );
    }
    return null;
  }
}
