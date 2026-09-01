import '../constants/mt_constants.dart';

/// بناء اسم الملف المحلي (§2.4): `<CleanTitle>_<HHmmss>.<ext>` —
/// الامتداد من اسم السيرفر (الافتراضي mp4)، قص العنوان 80، دعم كامل
/// للعربية واليونيكود (تُزال فقط المحارف غير الصالحة في أسماء الملفات).
String buildLocalFilename(
  String? title, {
  String? serverFilename,
  DateTime? now,
}) {
  var clean = (title ?? '')
      .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.length > MTConstants.filenameTitleMaxLength) {
    clean = clean.substring(0, MTConstants.filenameTitleMaxLength).trim();
  }
  if (clean.isEmpty) clean = 'video';

  final time = now ?? DateTime.now();
  final stamp = '${time.hour.toString().padLeft(2, '0')}'
      '${time.minute.toString().padLeft(2, '0')}'
      '${time.second.toString().padLeft(2, '0')}';

  return '${clean}_$stamp.${extensionOf(serverFilename)}';
}

/// امتداد اسم ملف السيرفر — أحرف/أرقام ≤5 بعد آخر نقطة، وإلا الافتراضي.
String extensionOf(String? serverFilename) {
  final name = serverFilename ?? '';
  final dot = name.lastIndexOf('.');
  if (dot > 0 && dot < name.length - 1) {
    final ext = name.substring(dot + 1).toLowerCase();
    if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext)) return ext;
  }
  return MTConstants.defaultMediaExtension;
}
