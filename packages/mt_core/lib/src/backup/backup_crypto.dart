import 'dart:convert';

import 'package:encrypt/encrypt.dart';

/// The file is in no known backup format: no valid header.
final class BackupFormatException implements Exception {
  const BackupFormatException([this.detail]);
  final String? detail;
}

/// The header is right but the key does not decrypt: cleared data, or
/// another device without the key imported. A terminal state, with no
/// retry; the answer is to import the key.
final class BackupKeyMismatchException implements Exception {
  const BackupKeyMismatchException();
}

/// Backup encryption (§5.4): AES-256-CBC from standard libraries **only**
/// (the lesson from the old Super: hand-rolled base64/utf8 helpers were
/// broken for non-ASCII). File shape:
/// `<header>\n<base64(IV)>\n<base64(ciphertext)>`.
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

  /// The file header if it is a known one, to identify the format before
  /// any decryption.
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

  /// Decrypts any of the three header formats. **No json.decode before this
  /// step** (rule §5.4). Throws [BackupFormatException] for a foreign file
  /// and [BackupKeyMismatchException] for a wrong key.
  static String decrypt({required String contents, required String keyBase64}) {
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

  // The exported key file, for restoring on another device.

  static String encodeKeyFile(String keyBase64) => '$keyHeaderV2\n$keyBase64\n';

  /// Reads a key file with any known header, new or either legacy one.
  /// Returns null for an invalid file. The key is exactly 32 bytes.
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
