import 'dart:io';

import 'package:synchronized/synchronized.dart';

enum LogLevel { debug, info, warn, error }

/// A diagnostic log in a ring file: trimmed to the last [maxLines] lines,
/// and sharing passes **mandatorily** through [sanitizeForShare], which
/// removes URLs, IP addresses, authentication headers and storage paths.
/// The app supplies the path from path_provider.
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
  static final RegExp _ipPattern = RegExp(
    r'\b\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?\b',
  );

  Future<void> log(
    String message, {
    LogLevel level = LogLevel.info,
    String? tag,
  }) => _lock.synchronized(() async {
    try {
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
    } on FileSystemException {
      // **Best effort by design.** A diagnostic log must never take down
      // the thing it is describing. The directory can go away underneath it
      // — Android wipes caches — and CI caught exactly that on Linux
      // (2026-09-09): the append succeeded, the file was gone by the time
      // the trim read it back, and `PathNotFoundException` surfaced out of
      // `LibraryEnricher.enrich`, failing a test about thumbnails for a
      // reason that had nothing to do with thumbnails.
    }
  });

  Future<void> error(String message, {Object? cause, String? tag}) => log(
    cause == null ? message : '$message: $cause',
    level: LogLevel.error,
    tag: tag,
  );

  /// **Under the same lock**: trimming (`_trimIfNeeded`) rewrites the whole
  /// file, and a read landing at that moment sees an empty or truncated
  /// file. That is a log screen flashing empty, and a test failing one time
  /// in ten.
  Future<String> readAll() => _lock.synchronized(() async {
    final file = File(filePath);
    return await file.exists() ? file.readAsString() : '';
  });

  Future<void> clear() => _lock.synchronized(() async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.writeAsString('', flush: true);
    }
  });

  /// The log text ready to share, after the mandatory sanitising.
  Future<String> readForShare() async => sanitizeForShare(await readAll());

  Future<void> _trimIfNeeded(File file) async {
    // The append above created it; it can still be gone by now.
    if (!await file.exists()) return;
    final lines = await file.readAsLines();
    if (lines.length > maxLines) {
      final kept = lines.sublist(lines.length - maxLines);
      await file.writeAsString('${kept.join('\n')}\n', flush: true);
    }
  }

  /// Replaces credentials, URLs, paths and IP addresses with opaque
  /// markers. **Order matters**: authentication before URLs.
  static String sanitizeForShare(String text) => text
      .replaceAll(_authPattern, '[AUTH]')
      .replaceAll(_urlPattern, '[URL]')
      .replaceAll(_filePattern, '[FILE]')
      .replaceAll(_ipPattern, '[IP]');
}
