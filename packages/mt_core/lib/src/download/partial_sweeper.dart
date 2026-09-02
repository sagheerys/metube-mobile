import 'dart:io';

import 'transfer.dart';

/// **كنس الملفات الجزئية اليتيمة (إصلاح خ-3).**
///
/// قتلُ التطبيق في منتصف سحب كبير يترك `<اسم>.part` على القرص، والاسم
/// الجديد بعد إعادة المحاولة مختلف (طابع `HHmmss`) فلا ينظّف القديم
/// أحد — **ولا كنس إقلاع في أي من التطبيقين**. مسح المكتبة يتجاهل
/// `.part` عمداً، فالمساحة تضيع بلا أن يراها المستخدم.
///
/// [olderThan] يحمي سحباً **جارياً الآن** من أن يُكنس تحت أقدامه.
Future<int> sweepPartialFiles(
  String directoryPath, {
  Duration olderThan = const Duration(hours: 6),
}) async {
  final dir = Directory(directoryPath);
  if (!await dir.exists()) return 0;
  final cutoff = DateTime.now().subtract(olderThan);
  var removed = 0;
  try {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith(Transfer.partSuffix)) continue;
      try {
        final stat = await entity.stat();
        if (stat.modified.isAfter(cutoff)) continue;
        await entity.delete();
        removed++;
      } on FileSystemException {
        // ملف مقفل أو حُذف بيننا — لا شيء يُفعل.
      }
    }
  } on FileSystemException {
    // مجلد بلا صلاحية قراءة ⇒ لا كنس، ولا انهيار إقلاع.
  }
  return removed;
}
