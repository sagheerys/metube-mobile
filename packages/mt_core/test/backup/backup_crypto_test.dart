import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('BackupCrypto', () {
    test('roundtrip v2: تشفير ثم فك بنص عربي', () async {
      final key = BackupCrypto.generateKeyBase64();
      const payload = '{"عنوان": "نص عربي كامل ✓", "n": 5}';
      final file = BackupCrypto.encrypt(plaintext: payload, keyBase64: key);
      expect(file, startsWith('MTF1\n'));
      expect(BackupCrypto.decrypt(contents: file, keyBase64: key), payload);
    });

    test('مفتاح خاطئ ⇒ BackupKeyMismatchException', () {
      final file = BackupCrypto.encrypt(
        plaintext: '{}',
        keyBase64: BackupCrypto.generateKeyBase64(),
      );
      expect(
        () => BackupCrypto.decrypt(
            contents: file, keyBase64: BackupCrypto.generateKeyBase64()),
        throwsA(isA<BackupKeyMismatchException>()),
      );
    });

    test('ترويسة غريبة ⇒ BackupFormatException (لا json.decode قبل الفك)',
        () {
      expect(
        () => BackupCrypto.decrypt(
            contents: '{"app": "MeTube Lite"}',
            keyBase64: BackupCrypto.generateKeyBase64()),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('ملف مبتور ⇒ BackupFormatException', () {
      expect(
        () => BackupCrypto.decrypt(
            contents: 'MTF1\nonly-iv',
            keyBase64: BackupCrypto.generateKeyBase64()),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('التنسيقان القديمان ترويستاهما معروفتان', () {
      expect(BackupCrypto.headerOf('MTBACKUP1\nx\ny'), 'MTBACKUP1');
      expect(BackupCrypto.headerOf('MTSBACKUP1\nx\ny'), 'MTSBACKUP1');
      expect(BackupCrypto.headerOf('WHATEVER\nx'), isNull);
    });

    test('ملف المفتاح: تصدير MTFKEY1 وقراءة الترويسات الثلاث', () {
      final key = BackupCrypto.generateKeyBase64();
      final file = BackupCrypto.encodeKeyFile(key);
      expect(file, 'MTFKEY1\n$key\n');
      expect(BackupCrypto.decodeKeyFile(file), key);
      expect(BackupCrypto.decodeKeyFile('MTKEY1\n$key\n'), key);
      expect(BackupCrypto.decodeKeyFile('MTSKEY1\n$key\n'), key);
    });

    test('ملف مفتاح غير صالح ⇒ null', () {
      expect(BackupCrypto.decodeKeyFile('WRONG\nabc\n'), isNull);
      expect(BackupCrypto.decodeKeyFile('MTFKEY1\nnot-base64!!\n'), isNull);
      expect(BackupCrypto.decodeKeyFile('MTFKEY1\naGk=\n'), isNull,
          reason: 'المفتاح يجب أن يكون 32 بايتاً');
    });
  });
}
