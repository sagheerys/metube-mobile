import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late MTLogger logger;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mtf_logger_');
    logger = MTLogger(
      filePath: '${tempDir.path}${Platform.pathSeparator}log.txt',
      maxLines: 5,
    );
  });
  tearDown(() => tempDir.delete(recursive: true));

  group('MTLogger: the ring file', () {
    test('appending with a level and a tag', () async {
      await logger.log('بدأ التحميل', tag: 'Engine');
      await logger.error('انقطاع', cause: 'timeout', tag: 'Net');
      final content = await logger.readAll();
      expect(content, contains('INFO [Engine] بدأ التحميل'));
      expect(content, contains('ERROR [Net] انقطاع: timeout'));
    });

    test('trimming to the last maxLines lines', () async {
      for (var i = 1; i <= 8; i++) {
        await logger.log('سطر $i');
      }
      final lines = (await logger.readAll()).trim().split('\n');
      expect(lines, hasLength(5));
      expect(lines.first, contains('سطر 4'));
      expect(lines.last, contains('سطر 8'));
    });

    test('clear empties it', () async {
      await logger.log('شيء');
      await logger.clear();
      expect(await logger.readAll(), isEmpty);
    });

    test(
      'readAll on a file that does not exist yet gives empty text',
      () async {
        expect(await logger.readAll(), '');
      },
    );
  });

  group('sanitizeForShare: the mandatory scrubbing', () {
    test('it masks credentials, URLs, paths and IP addresses', () {
      const raw =
          'Authorization: Basic dXNlcjpwQHNz fetching '
          'https://metube.example.com/history from 192.168.1.10:8081 saved '
          '/storage/emulated/0/Download/MeTube_Lite/فيديو خاص.mp4 done';
      final clean = MTLogger.sanitizeForShare(raw);
      expect(clean, isNot(contains('dXNlcjpw')));
      expect(clean, isNot(contains('metube.example.com')));
      expect(clean, isNot(contains('192.168.1.10')));
      expect(clean, isNot(contains('فيديو خاص')));
      expect(clean, contains('[AUTH]'));
      expect(clean, contains('[URL]'));
      expect(clean, contains('[IP]'));
      expect(clean, contains('[FILE]'));
    });

    test('readForShare passes through the scrubbing automatically', () async {
      await logger.log('probe https://secret.example.com ok');
      expect(await logger.readForShare(), isNot(contains('secret.example')));
    });
  });

  test(
    '**the guard**: a log the filesystem refuses does not reach the caller',
    () async {
      // Reproduces, deterministically, what CI hit on Linux on
      // 2026-09-09: the log file could not be written and the exception
      // escaped `MTLogger.log` into `LibraryEnricher.enrich`, failing a
      // test about thumbnails. Here the parent of the log path is a file,
      // so creating the directory throws.
      final tmp = Directory.systemTemp.createTempSync('mt_logger_blocked_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final blocker = File('${tmp.path}/blocked')..writeAsStringSync('x');
      final blocked = MTLogger(filePath: '${blocker.path}/app.log');

      await blocked.log('this must be dropped, not thrown');

      expect(await blocked.readAll(), isEmpty);
    },
  );
}
