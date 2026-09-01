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

  group('MTLogger — الملف الحلقي (م-32)', () {
    test('إلحاق بمستوى ووسم', () async {
      await logger.log('بدأ التحميل', tag: 'Engine');
      await logger.error('انقطاع', cause: 'timeout', tag: 'Net');
      final content = await logger.readAll();
      expect(content, contains('INFO [Engine] بدأ التحميل'));
      expect(content, contains('ERROR [Net] انقطاع: timeout'));
    });

    test('القص لآخر maxLines سطراً', () async {
      for (var i = 1; i <= 8; i++) {
        await logger.log('سطر $i');
      }
      final lines = (await logger.readAll()).trim().split('\n');
      expect(lines, hasLength(5));
      expect(lines.first, contains('سطر 4'));
      expect(lines.last, contains('سطر 8'));
    });

    test('clear يمسح', () async {
      await logger.log('شيء');
      await logger.clear();
      expect(await logger.readAll(), isEmpty);
    });

    test('readAll لملف لم يُنشأ بعد ⇒ نص فارغ', () async {
      expect(await logger.readAll(), '');
    });
  });

  group('sanitizeForShare — التعقيم الإلزامي', () {
    test('يحجب المصادقة والروابط والمسارات وIP', () {
      const raw = 'Authorization: Basic eWFzaXI6cEBzcw== fetching '
          'https://metube.example.com/history from 192.168.1.10:8081 saved '
          '/storage/emulated/0/Download/MeTube_Lite/فيديو خاص.mp4 done';
      final clean = MTLogger.sanitizeForShare(raw);
      expect(clean, isNot(contains('eWFzaXI6')));
      expect(clean, isNot(contains('metube.example.com')));
      expect(clean, isNot(contains('192.168.1.10')));
      expect(clean, isNot(contains('فيديو خاص')));
      expect(clean, contains('[AUTH]'));
      expect(clean, contains('[URL]'));
      expect(clean, contains('[IP]'));
      expect(clean, contains('[FILE]'));
    });

    test('readForShare يمر بالتعقيم تلقائياً', () async {
      await logger.log('probe https://secret.example.com ok');
      expect(await logger.readForShare(), isNot(contains('secret.example')));
    });
  });
}
