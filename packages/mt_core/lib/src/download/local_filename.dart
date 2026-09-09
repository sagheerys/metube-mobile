import '../constants/mt_constants.dart';

/// Building the local filename (§2.4): `<CleanTitle>_<HHmmss>.<ext>`. The
/// extension comes from the server's name (mp4 by default), the title is
/// truncated at 80, and Arabic and Unicode are fully supported: only
/// characters invalid in filenames are removed.
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

/// The extension from the server's filename: letters or digits, at most 5
/// after the final dot, otherwise the default.
String extensionOf(String? serverFilename) {
  final name = serverFilename ?? '';
  final dot = name.lastIndexOf('.');
  if (dot > 0 && dot < name.length - 1) {
    final ext = name.substring(dot + 1).toLowerCase();
    if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext)) return ext;
  }
  return MTConstants.defaultMediaExtension;
}
