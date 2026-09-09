import 'dart:convert';

import '../constants/mt_constants.dart';
import '../storage/key_value_store.dart';
import '../storage/secret_store.dart';
import 'backup_crypto.dart';

part 'backup_legacy.dart';

/// `plain` is the format written today; the other three are **read-only**,
/// for migration from earlier releases.
enum BackupFormat { plain, v2, legacyLite, legacySuper }

class ImportResult {
  const ImportResult({required this.format, required this.keysRestored});
  final BackupFormat format;
  final int keysRestored;
}

/// The backup service (§5.4): writes v2 `MTF1` and reads all three formats
/// (the two legacy ones **read-only**, for migration). The payload is every
/// key in §5.1 plus `username`; **the password never goes in**. It works on
/// strings, since files on disk are the app's business.
class BackupService {
  BackupService({
    required this.store,
    required this.secrets,
    required this.mutex,
    required this.variant,
  });

  final KeyValueStore store;
  final SecretStore secrets;
  final PrefsMutex mutex;

  /// `lite` or `super`, recorded inside the file for documentation only;
  /// import accepts either.
  final String variant;

  /// Keys holding server URLs, which may be pasted as
  /// `https://user:pass@host`.
  static const _urlKeys = {
    'server_url',
    'local_url',
    'active_url',
    'external_urls',
  };

  /// **Strip credentials embedded in a URL before backing it up.**
  /// Excluding the password from the backup is correct, but someone
  /// who pastes `https://user:pass@host` as the server URL puts it in an
  /// ordinary string key, so it entered the backup despite the rule.
  static Object? _sanitize(String key, Object? value) {
    if (!_urlKeys.contains(key)) return value;
    if (value is String) return stripUrlCredentials(value);
    if (value is List) {
      return [for (final v in value) stripUrlCredentials(v.toString())];
    }
    return value;
  }

  /// Returns the URL without `user:pass@`, and anything that is not a URL
  /// unchanged.
  static String stripUrlCredentials(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.userInfo.isEmpty) return raw;
    return uri.replace(userInfo: '').toString();
  }

  /// The key that decrypts legacy backups **if one exists**. It is never
  /// generated.
  ///
  /// It used to generate a key when it found none, which was right while
  /// writing was encrypted. After encryption was removed (2026-09-04),
  /// generating became pure waste: a new key decrypts nothing, and then
  /// decryption fails with a message further from the cause. The absence is
  /// itself the answer: [BackupKeyMismatchException].
  Future<String> _decryptionKey() async {
    final stored = await secrets.read(SecretKeys.backupAesKey);
    if (stored == null || stored.isEmpty) {
      throw const BackupKeyMismatchException();
    }
    return stored;
  }

  /// **A plain-text export with no secret in it at all** (decision
  /// 2026-09-04).
  ///
  /// `MTF1` used to be encrypted with a key living in secure storage, which
  /// dies with "clear data" or a reinstall, leaving an **orphan** backup
  /// that opens only if the user exported the key, which nobody does. And
  /// the content itself, links, titles, playlists and tags, is visible to
  /// anyone who opens the app anyway.
  ///
  /// [SecretKeys.username] is **no longer backed up** either: the password
  /// never was, so the user re-enters it regardless, and a username without
  /// a password opens nothing. Leaving it out makes the file secret-free.
  ///
  /// A full snapshot under the lock, so a concurrent writer cannot tear it.
  /// Indented on purpose: an unencrypted file read by eye is a
  /// human-readable escape hatch that costs nothing.
  Future<String> exportToString() => mutex.run(() async {
    final prefsMap = <String, dynamic>{};
    for (final key in await store.keys()) {
      final cell = _encodeCell(_sanitize(key, await store.get(key)));
      if (cell != null) prefsMap[key] = cell;
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'MTF',
      'variant': variant,
      'version': 3,
      'backupDate': DateTime.now().toIso8601String(),
      'prefs': prefsMap,
    });
  });

  /// Imports any format: the new plain text or the three legacy encrypted
  /// ones.
  ///
  /// **The header is checked first** (rule §5.4: never `json.decode` an
  /// encrypted file before decrypting it), and its absence together with a
  /// leading `{` means the plain format.
  Future<ImportResult> importFromString(String contents) async {
    final header = BackupCrypto.headerOf(contents);
    if (header == null) {
      if (!contents.trimLeft().startsWith('{')) {
        throw const BackupFormatException('unknown header');
      }
      return _applyPlain(contents);
    }
    final plaintext = BackupCrypto.decrypt(
      contents: contents,
      keyBase64: await _decryptionKey(),
    );
    final decoded = json.decode(plaintext);
    if (decoded is! Map) throw const BackupFormatException('not a map');
    final payload = Map<String, dynamic>.from(decoded);

    return switch (header) {
      BackupCrypto.headerLegacyLite => _applyLegacyLite(payload),
      // v2 and MTSBACKUP1 share the same typed prefs structure.
      _ => _applyTypedPrefs(
        payload,
        header == BackupCrypto.headerV2
            ? BackupFormat.v2
            : BackupFormat.legacySuper,
      ),
    };
  }

  Future<ImportResult> _applyPlain(String contents) async {
    final Object? decoded;
    try {
      decoded = json.decode(contents);
    } on FormatException {
      throw const BackupFormatException('bad json');
    }
    if (decoded is! Map || decoded['app'] != 'MTF') {
      throw const BackupFormatException('not an MTF backup');
    }
    return _applyTypedPrefs(
      Map<String, dynamic>.from(decoded),
      BackupFormat.plain,
    );
  }

  Future<ImportResult> _applyTypedPrefs(
    Map<String, dynamic> payload,
    BackupFormat format,
  ) async {
    final prefs = (payload['prefs'] as Map?) ?? const {};
    var restored = 0;
    await mutex.run(() async {
      // **All-or-nothing restore.** A failure on key 40 of 200
      // used to leave a **hybrid device**: an offline index from another
      // phone pointing at missing titles, with no rollback and no message
      // saying where it stopped.
      final rollback = <String, Object?>{};
      for (final key in prefs.keys) {
        rollback[key.toString()] = await store.get(key.toString());
      }
      try {
        for (final entry in prefs.entries) {
          if (await _applyCell(entry.key.toString(), entry.value)) restored++;
        }
        if (format == BackupFormat.legacyLite ||
            format == BackupFormat.legacySuper) {
          await _migrateLegacyShapes();
        }
      } on Object {
        for (final entry in rollback.entries) {
          entry.value == null
              ? await store.remove(entry.key)
              : await _restoreRaw(entry.key, entry.value!);
        }
        rethrow;
      }
    });
    await _restoreUsername(
      ((payload['secure'] as Map?) ?? const {})['username']?.toString() ??
          (payload['settings'] as Map?)?['username']?.toString(),
    );
    return ImportResult(format: format, keysRestored: restored);
  }

  static const int _secondsInDay = 86400;
  static const String _positionPrefix = 'playback_pos_';

  Future<void> _restoreUsername(String? username) async {
    if (username != null && username.isNotEmpty) {
      await secrets.write(SecretKeys.username, username);
    }
  }

  static dynamic _encodeCell(Object? value) => switch (value) {
    String v => {'t': 's', 'v': v},
    bool v => {'t': 'b', 'v': v},
    int v => {'t': 'i', 'v': v},
    double v => {'t': 'd', 'v': v},
    List v => {'t': 'l', 'v': v.map((e) => e.toString()).toList()},
    _ => null,
  };

  /// Puts a value back as it was, to roll back a restore that failed
  /// halfway.
  Future<void> _restoreRaw(String key, Object value) async {
    switch (value) {
      case String v:
        await store.setString(key, v);
      case bool v:
        await store.setBool(key, v);
      case int v:
        await store.setInt(key, v);
      case double v:
        await store.setDouble(key, v);
      case List v:
        await store.setStringList(key, [for (final e in v) e.toString()]);
      default:
        await store.remove(key);
    }
  }

  Future<bool> _applyCell(String key, dynamic cell) async {
    if (cell is! Map) return false;
    final v = cell['v'];
    switch (cell['t']) {
      case 's':
        await store.setString(key, v.toString());
      case 'b':
        await store.setBool(key, v == true);
      case 'i':
        if (v is! num) return false;
        await store.setInt(key, v.toInt());
      case 'd':
        if (v is! num) return false;
        await store.setDouble(key, v.toDouble());
      case 'l':
        if (v is! List) return false;
        await store.setStringList(key, v.map((e) => e.toString()).toList());
      default:
        return false;
    }
    return true;
  }
}
