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

    test('every write and every clear is announced', () async {
      var heard = 0;
      final sub = logger.changes.listen((_) => heard++);
      await logger.log('one');
      await logger.error('two');
      await logger.clear();
      await Future<void>.delayed(Duration.zero);
      expect(heard, 3);
      await sub.cancel();
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

    test('a host name in a failed lookup is masked', () {
      final out = MTLogger.sanitizeForShare(
        "NetworkException: The connection errored: Failed host lookup: "
        "'my-nas.example.org' at /history",
      );
      expect(out, isNot(contains('my-nas')));
      expect(out, contains('/history'));
    });

    test('the Windows player\'s lines, IPv6 and forward-slash paths are '
        'masked too', () {
      // Security review 2026-11-05: these passed through a shared log as
      // they were.
      final out = MTLogger.sanitizeForShare(
        '[ffmpeg] tcp: Failed to resolve hostname my-nas.duckdns.org: no '
        'address\n'
        '[ffmpeg] tcp: address = mtube.example.org, port 443\n'
        'connect to 2001:db8:85a3::8a2e:370:7334 and [fe80::1]:8081 failed\n'
        'saved to C:/Users/Yasir Sg/Videos/clip.mp4',
      );
      expect(out, isNot(contains('my-nas')));
      expect(out, isNot(contains('mtube.example')));
      expect(out, isNot(contains('2001:db8')));
      expect(out, isNot(contains('fe80')));
      expect(out, isNot(contains('Yasir')));
      expect(out, contains('[HOST]'));
      expect(out, contains('[IP]'));
      expect(out, contains('[FILE]'));
    });

    test('a clock time is not taken for an address', () {
      const line = '2026-11-10T14:34:30.123 INFO [player] position 01:02:03';
      expect(MTLogger.sanitizeForShare(line), line);
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

  /// Cloudflare Access: the log screen shows the file
  /// as it is, and the share button sanitises it, so the service token has
  /// to be handled both when it is written and when it is shared.
  group('the Cloudflare Access pair in the log', () {
    const id = '4c1f0d7a.access';
    const secret = '9a7e11c0b2d4f6a8';

    test('sanitizeForShare replaces both values, whatever the spelling', () {
      for (final line in [
        'sent CF-Access-Client-Id: $id and CF-Access-Client-Secret: $secret',
        'sent CF-Access-Client-Id=$id CF-Access-Client-Secret=$secret',
        'sent cf-access-client-id: $id cf-access-client-secret: $secret',
        'headers {CF-Access-Client-Id: $id, CF-Access-Client-Secret: $secret}',
      ]) {
        final clean = MTLogger.sanitizeForShare(line);
        expect(clean, isNot(contains(id)), reason: line);
        expect(clean, isNot(contains(secret)), reason: line);
        expect(clean, contains('[AUTH]'), reason: line);
      }
    });

    test(
      'a line is already scrubbed in the file the log screen shows',
      () async {
        // Defect: the value sat in the log file for as long as the log did
        // and was visible on the logs screen, which reads the raw file.
        await logger.log('headers CF-Access-Client-Id: $id');
        await logger.error(
          'failed',
          cause: 'CF-Access-Client-Secret: $secret rejected',
        );
        final shown = await logger.readAll();
        expect(shown, isNot(contains(id)));
        expect(shown, isNot(contains(secret)));
        expect(shown, contains('failed'), reason: 'the rest of the line stays');
      },
    );

    test(
      'the write-time scrub leaves ordinary lines exactly as written',
      () async {
        // Nothing else changes: only this pattern is applied at write time. URLs and
        // addresses stay readable on the device and are removed when shared.
        await logger.log('fetching https://metube.example.com/history ok');
        expect(
          await logger.readAll(),
          contains('fetching https://metube.example.com/history ok'),
        );
      },
    );
  });
}
