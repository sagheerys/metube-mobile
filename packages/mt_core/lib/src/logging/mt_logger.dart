import 'dart:io';

import 'package:synchronized/synchronized.dart';

enum LogLevel { debug, info, warn, error }

/// سجل تشخيصي بملف حلقي (م-32): يُقص لآخر [maxLines] سطراً، والمشاركة
/// تمر **إلزامياً** بـ [sanitizeForShare] (حذف الروابط وIP وترويسات
/// المصادقة ومسارات التخزين). التطبيق يمرر المسار من path_provider.
class MTLogger {
  MTLogger({required this.filePath, this.maxLines = 1000});

  final String filePath;
  final int maxLines;
  final Lock _lock = Lock();

  static final RegExp _authPattern = RegExp(
    r'(?:Basic|Bearer)\s+[A-Za-z0-9+/=._-]{8,}',
    caseSensitive: false,
  );
  static final RegExp _urlPattern = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  );
  static final RegExp _filePattern = RegExp(r'/storage/emulated/0/[^\s\]),]+');
  static final RegExp _ipPattern =
      RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?\b');

  Future<void> log(
    String message, {
    LogLevel level = LogLevel.info,
    String? tag,
  }) =>
      _lock.synchronized(() async {
        final file = File(filePath);
        await file.parent.create(recursive: true);
        final stamp = DateTime.now().toIso8601String();
        final tagPart = tag == null ? '' : '[$tag] ';
        await file.writeAsString(
          '$stamp ${level.name.toUpperCase()} $tagPart$message\n',
          mode: FileMode.append,
          flush: true,
        );
        await _trimIfNeeded(file);
      });

  Future<void> error(String message, {Object? cause, String? tag}) => log(
        cause == null ? message : '$message: $cause',
        level: LogLevel.error,
        tag: tag,
      );

  Future<String> readAll() async {
    final file = File(filePath);
    return await file.exists() ? file.readAsString() : '';
  }

  Future<void> clear() => _lock.synchronized(() async {
        final file = File(filePath);
        if (await file.exists()) {
          await file.writeAsString('', flush: true);
        }
      });

  /// نص السجل جاهزاً للمشاركة بعد التعقيم الإلزامي.
  Future<String> readForShare() async => sanitizeForShare(await readAll());

  Future<void> _trimIfNeeded(File file) async {
    final lines = await file.readAsLines();
    if (lines.length > maxLines) {
      final kept = lines.sublist(lines.length - maxLines);
      await file.writeAsString('${kept.join('\n')}\n', flush: true);
    }
  }

  /// استبدال الاعتمادات والروابط والمسارات وعناوين IP بعلامات مبهمة —
  /// **الترتيب مهم**: المصادقة قبل الروابط.
  static String sanitizeForShare(String text) => text
      .replaceAll(_authPattern, '[AUTH]')
      .replaceAll(_urlPattern, '[URL]')
      .replaceAll(_filePattern, '[FILE]')
      .replaceAll(_ipPattern, '[IP]');
}
