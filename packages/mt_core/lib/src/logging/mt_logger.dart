import 'dart:async';
import 'dart:io';

import 'package:synchronized/synchronized.dart';

enum LogLevel { debug, info, warn, error }

/// A diagnostic log in a ring file: trimmed to the last [maxLines] lines,
/// and sharing passes **mandatorily** through [sanitizeForShare], which
/// removes URLs, IP addresses, authentication headers (Basic, Bearer and the
/// Cloudflare Access pair) and storage paths. The app supplies the path from
/// path_provider.
///
/// **One thing is removed earlier, when a line is written**: the value of a
/// `CF-Access-Client-Id` or `CF-Access-Client-Secret` header. The logs screen
/// shows the file as it is, so a service token that reached it would be
/// readable by anyone holding the phone. Everything else is kept readable on
/// the device and removed only when shared.
class MTLogger {
  MTLogger({required this.filePath, this.maxLines = 1000});

  final String filePath;
  final int maxLines;
  final Lock _lock = Lock();
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires after every write and every clear, so a screen showing the log
  /// can follow it live instead of asking to be refreshed.
  Stream<void> get changes => _changes.stream;

  static final RegExp _authPattern = RegExp(
    r'(?:Basic|Bearer)\s+[A-Za-z0-9+/=._-]+',
    caseSensitive: false,
  );
  // A cookie is a password by another name, the whole header with it.
  static final RegExp _cookiePattern = RegExp(
    r'((?:Set-)?Cookie\s*:\s*)[^\n]+|CF_Authorization=[^\s;]+',
    caseSensitive: false,
  );
  // The header name and separator are kept so the line still says which
  // header was involved; only the value goes.
  static final RegExp _cloudflarePattern = RegExp(
    r'''(CF-Access-Client-(?:Id|Secret)["']?\s*[:=]\s*["']?)[^\s,;}"')\]]+''',
    caseSensitive: false,
  );
  static final RegExp _urlPattern = RegExp(
    r'(?:https?|content|file)://[^\s<>"]+',
    caseSensitive: false,
  );
  // A file name has spaces in it, so a path runs to the end of the line or
  // to a quote or bracket; stopping at the first space left the title.
  // Android's storage and app folders, and Windows' drive paths, written
  // with either slash (the Windows player writes forward ones).
  static final RegExp _filePattern = RegExp(
    r'''(?:/storage/|/data/|/sdcard/|\b[A-Za-z]:[\\/])[^\n'"\]|)]+''',
  );
  // A host name has no scheme of its own here: the socket's own words.
  static final RegExp _hostLookupPattern = RegExp(
    r"(host lookup: ')[^']+'",
    caseSensitive: false,
  );
  // The Windows player's own words for a server it reached or failed to.
  static final RegExp _hostWordsPattern = RegExp(
    r'((?:\baddress\s*=|resolve hostname)\s*)[^\s,;]+',
    caseSensitive: false,
  );
  static final RegExp _ipPattern = RegExp(
    r'\b\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?\b',
  );
  // Five groups or more, or a `::`: a clock time ("14:34:30") has three
  // groups and no `::`, and stays as it is.
  static final RegExp _ipv6Pattern = RegExp(
    r'\[?(?:\b[0-9a-f]{1,4}(?::[0-9a-f]{1,4}){4,7}\b'
    r'|(?:\b[0-9a-f]{1,4})?(?::[0-9a-f]{1,4})*::'
    r'(?:[0-9a-f]{1,4}(?::[0-9a-f]{1,4})*)?)\]?(?::\d+)?',
    caseSensitive: false,
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
        '$stamp ${level.name.toUpperCase()} $tagPart${_hideAccess(message)}\n',
        mode: FileMode.append,
        flush: true,
      );
      await _trimIfNeeded(file);
      _changes.add(null);
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
    _changes.add(null);
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

  static String _hideAccess(String text) =>
      text.replaceAllMapped(_cloudflarePattern, (m) => '${m[1]}[AUTH]');

  /// Replaces credentials, URLs, paths and IP addresses with opaque
  /// markers. **Order matters**: authentication before URLs.
  static String sanitizeForShare(String text) =>
      _hideAccess(text)
          .replaceAll(_authPattern, '[AUTH]')
          .replaceAllMapped(_cookiePattern, (m) => '${m[1] ?? ''}[COOKIE]')
          .replaceAll(_urlPattern, '[URL]')
          .replaceAll(_filePattern, '[FILE]')
          .replaceAllMapped(_hostLookupPattern, (m) => "${m[1]}[HOST]'")
          .replaceAllMapped(_hostWordsPattern, (m) => '${m[1]}[HOST]')
          .replaceAll(_ipPattern, '[IP]')
          .replaceAll(_ipv6Pattern, '[IP]');
}
