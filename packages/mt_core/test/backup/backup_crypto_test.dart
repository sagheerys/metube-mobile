import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('BackupCrypto', () {
    test('a v2 round trip: encrypt then decrypt Arabic text', () async {
      final key = BackupCrypto.generateKeyBase64();
      const payload = '{"عنوان": "نص عربي كامل ✓", "n": 5}';
      final file = BackupCrypto.encrypt(plaintext: payload, keyBase64: key);
      expect(file, startsWith('MTF1\n'));
      expect(BackupCrypto.decrypt(contents: file, keyBase64: key), payload);
    });

    test('the wrong key raises BackupKeyMismatchException', () {
      final file = BackupCrypto.encrypt(
        plaintext: '{}',
        keyBase64: BackupCrypto.generateKeyBase64(),
      );
      expect(
        () => BackupCrypto.decrypt(
          contents: file,
          keyBase64: BackupCrypto.generateKeyBase64(),
        ),
        throwsA(isA<BackupKeyMismatchException>()),
      );
    });

    test('an unknown header raises BackupFormatException: no json.decode before decrypting', () {
      expect(
        () => BackupCrypto.decrypt(
          contents: '{"app": "MeTube Lite"}',
          keyBase64: BackupCrypto.generateKeyBase64(),
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('a truncated file raises BackupFormatException', () {
      expect(
        () => BackupCrypto.decrypt(
          contents: 'MTF1\nonly-iv',
          keyBase64: BackupCrypto.generateKeyBase64(),
        ),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('both legacy formats have recognised headers', () {
      expect(BackupCrypto.headerOf('MTBACKUP1\nx\ny'), 'MTBACKUP1');
      expect(BackupCrypto.headerOf('MTSBACKUP1\nx\ny'), 'MTSBACKUP1');
      expect(BackupCrypto.headerOf('WHATEVER\nx'), isNull);
    });

    test('the key file: exporting MTFKEY1 and reading all three headers', () {
      final key = BackupCrypto.generateKeyBase64();
      final file = BackupCrypto.encodeKeyFile(key);
      expect(file, 'MTFKEY1\n$key\n');
      expect(BackupCrypto.decodeKeyFile(file), key);
      expect(BackupCrypto.decodeKeyFile('MTKEY1\n$key\n'), key);
      expect(BackupCrypto.decodeKeyFile('MTSKEY1\n$key\n'), key);
    });

    test('an invalid key file gives null', () {
      expect(BackupCrypto.decodeKeyFile('WRONG\nabc\n'), isNull);
      expect(BackupCrypto.decodeKeyFile('MTFKEY1\nnot-base64!!\n'), isNull);
      expect(
        BackupCrypto.decodeKeyFile('MTFKEY1\naGk=\n'),
        isNull,
        reason: 'المفتاح يجب أن يكون 32 بايتاً',
      );
    });
  });
}
