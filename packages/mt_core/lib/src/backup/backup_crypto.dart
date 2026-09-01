import 'dart:convert';

import 'package:encrypt/encrypt.dart';

/// الملف ليس بأي تنسيق نسخ احتياطي معروف (لا ترويسة صالحة).
final class BackupFormatException implements Exception {
  const BackupFormatException([this.detail]);
  final String? detail;
}

/// الترويسة صحيحة لكن المفتاح لا يفك — Clear Data أو جهاز آخر بلا
/// استيراد المفتاح. حالة نهائية: لا إعادة محاولة، والحل استيراد المفتاح.
final class BackupKeyMismatchException implements Exception {
  const BackupKeyMismatchException();
}

/// تشفير النسخ الاحتياطي (§5.4) — AES-256-CBC من مكتبات قياسية **فقط**
/// (درس Super: دوال base64/utf8 اليدوية كانت معطوبة لغير-ASCII).
/// شكل الملف: `<الترويسة>\n<base64(IV)>\n<base64(ciphertext)>`.
abstract final class BackupCrypto {
  static const String headerV2 = 'MTF1';
  static const String headerLegacyLite = 'MTBACKUP1';
  static const String headerLegacySuper = 'MTSBACKUP1';
  static const List<String> knownHeaders = [
    headerV2,
    headerLegacyLite,
    headerLegacySuper,
  ];

  static const String keyHeaderV2 = 'MTFKEY1';
  static const List<String> knownKeyHeaders = [
    keyHeaderV2,
    'MTKEY1', // مفتاح Lite القديم
    'MTSKEY1', // مفتاح Super القديم
  ];

  static String generateKeyBase64() => Key.fromSecureRandom(32).base64;

  /// ترويسة الملف إن كانت معروفة — لتمييز التنسيق قبل أي فك.
  static String? headerOf(String contents) {
    final firstLine = contents.split('\n').first.trim();
    return knownHeaders.contains(firstLine) ? firstLine : null;
  }

  static String encrypt({
    required String plaintext,
    required String keyBase64,
    String header = headerV2,
  }) {
    final key = Key.fromBase64(keyBase64);
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final ciphertext = encrypter.encrypt(plaintext, iv: iv);
    return '$header\n${iv.base64}\n${ciphertext.base64}';
  }

  /// فك أي تنسيق من الترويسات الثلاث. **لا json.decode قبل هذا الفك**
  /// (قاعدة §5.4). يرمي [BackupFormatException] لملف غريب،
  /// و[BackupKeyMismatchException] لمفتاح خاطئ.
  static String decrypt({
    required String contents,
    required String keyBase64,
  }) {
    if (headerOf(contents) == null) {
      throw const BackupFormatException('unknown header');
    }
    final lines = contents.split('\n');
    if (lines.length < 3) throw const BackupFormatException('truncated');
    try {
      final iv = IV.fromBase64(lines[1].trim());
      final ciphertext = Encrypted.fromBase64(lines[2].trim());
      final key = Key.fromBase64(keyBase64);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      return encrypter.decrypt(ciphertext, iv: iv);
    } catch (_) {
      throw const BackupKeyMismatchException();
    }
  }

  // ── ملف المفتاح المُصدَّر (تصدير/استيراد للاستعادة على جهاز آخر) ──

  static String encodeKeyFile(String keyBase64) =>
      '$keyHeaderV2\n$keyBase64\n';

  /// يقرأ ملف مفتاح بأي ترويسة معروفة (الجديدة أو القديمتين) —
  /// null لملف غير صالح. المفتاح 32 بايتاً بالضبط.
  static String? decodeKeyFile(String contents) {
    final lines = contents.split('\n');
    if (lines.length < 2) return null;
    if (!knownKeyHeaders.contains(lines[0].trim())) return null;
    final keyBase64 = lines[1].trim();
    try {
      return base64.decode(keyBase64).length == 32 ? keyBase64 : null;
    } on FormatException {
      return null;
    }
  }
}
