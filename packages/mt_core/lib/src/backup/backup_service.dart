import 'dart:convert';

import '../constants/mt_constants.dart';
import '../download/pending_downloads.dart';
import '../download/trashcan_probe.dart';
import '../storage/artwork_index.dart';
import '../storage/key_value_store.dart';
import '../storage/secret_store.dart';
import '../update/update_prefs.dart';
import 'backup_addresses.dart';
import 'backup_crypto.dart';

part 'backup_cells.dart';
part 'backup_legacy.dart';

/// `plain` is the format written today; the other three are **read-only**,
/// for migration from earlier releases.
enum BackupFormat { plain, v2, legacyLite, legacySuper }

class ImportResult {
  const ImportResult({
    required this.format,
    required this.keysRestored,
    this.signInCleared = false,
  });
  final BackupFormat format;
  final int keysRestored;

  /// The file pointed the app at a server address it did not know, so the
  /// password and the Cloudflare token kept here were dropped rather than
  /// sent there; the user types them again for the new address.
  final bool signInCleared;
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

  /// **Keys that describe this phone's dealings with the server, not the
  /// user's data.** A pending download is a promise *this* process made;
  /// restored on another phone it would have that phone pull the file and
  /// delete it from the server while the first is still pulling it. The
  /// trashcan flag is a fact about one container, and travels with the
  /// backup to a server it was never measured on. Which version's "what's
  /// new" this install has seen is about the installed app: a restore from
  /// an older backup would show a sheet already read, or show one on a
  /// fresh install. The covers kept as files are paths on this device:
  /// restored elsewhere they point at nothing, and the clips they stand
  /// for show no cover at all instead of fetching theirs again.
  static const _deviceOnlyKeys = {
    KeptCoverIndex.keptKey,
    PendingDownloadsStore.prefsKey,
    TrashcanProbe.prefsKey,
    UpdatePrefs.lastSeenVersionKey,
    UpdatePrefs.notesKey,
  };

  /// Returns the URL without `user:pass@`, and anything that is not a URL
  /// unchanged.
  static String stripUrlCredentials(String raw) =>
      BackupAddresses.stripCredentials(raw);

  /// The server a plain backup points at, or null (no address, or not the
  /// plain format). Shown before a restore, so the user sees where the app
  /// will connect, and a file planted by someone else names its server.
  static String? serverOf(String contents) {
    try {
      final decoded = json.decode(contents);
      if (decoded is! Map || decoded['app'] != 'MTF') return null;
      final prefs = decoded['prefs'];
      return prefs is Map ? BackupAddresses.serverIn(prefs) : null;
    } on FormatException {
      return null;
    }
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
      if (_deviceOnlyKeys.contains(key)) continue;
      final cell = _encodeCell(BackupAddresses.sanitize(await store.get(key)));
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
    var newServer = false;
    await mutex.run(() async {
      final before = await BackupAddresses.knownServers(store);
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
          // A file written by this version carries none; one edited by
          // hand, or by a build between two releases, might.
          if (_deviceOnlyKeys.contains(entry.key.toString())) continue;
          if (await _applyCell(entry.key.toString(), entry.value)) restored++;
        }
        if (format == BackupFormat.legacyLite ||
            format == BackupFormat.legacySuper) {
          await _migrateLegacyShapes();
        }
        // Only the plain format can come from someone else: the encrypted
        // ones open with this device's own key. Switching between the home
        // and the outside address of one server is not a new server either:
        // both were known before.
        newServer =
            format == BackupFormat.plain &&
            !before.containsAll(await BackupAddresses.knownServers(store));
      } on Object {
        for (final entry in rollback.entries) {
          entry.value == null
              ? await store.remove(entry.key)
              : await _restoreRaw(entry.key, entry.value!);
        }
        rethrow;
      }
    });
    if (newServer) {
      for (final key in const [
        SecretKeys.password,
        SecretKeys.cfAccessClientId,
        SecretKeys.cfAccessClientSecret,
      ]) {
        await secrets.delete(key);
      }
    }
    // Only the old encrypted formats carried a username, and they open only
    // with this device's key; the plain format never writes one, so one
    // found there was put in by hand.
    if (format != BackupFormat.plain) {
      await _restoreUsername(
        ((payload['secure'] as Map?) ?? const {})['username']?.toString() ??
            (payload['settings'] as Map?)?['username']?.toString(),
      );
    }
    return ImportResult(
      format: format,
      keysRestored: restored,
      signInCleared: newServer,
    );
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
}
