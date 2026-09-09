// Gate 6: verifying the migration of a real legacy Super backup
// (`MTSBACKUP1`). It imports the file with its key into an in-memory store
// and prints **counts only**: no URL, no filename and no credential (the
// same sanitising rule as the diagnostic log).
//
// dart tool/verify_legacy_backup.dart <backup.json> <key.txt>
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:mt_core/mt_core.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('usage: dart tool/verify_legacy_backup.dart <backup> <key>');
    exit(64);
  }
  final backup = File(args[0]);
  final keyFile = File(args[1]);
  if (!backup.existsSync() || !keyFile.existsSync()) {
    print('file not found');
    exit(66);
  }

  final store = MemoryKeyValueStore();
  final secrets = MemorySecretStore();
  final service = BackupService(
    store: store,
    secrets: secrets,
    mutex: PrefsMutex(),
    variant: 'super',
  );

  final contents = backup.readAsStringSync();
  print('header: ${BackupCrypto.headerOf(contents)}');

  // The key first: a backup from another device cannot be decrypted with
  // this device's key. (`importKeyFile` was removed from the service along
  // with the whole key concept in 2026-09-04, and this is a manual
  // verification tool that seeds the key straight into an in-memory secret
  // store.)
  final keyBase64 = BackupCrypto.decodeKeyFile(keyFile.readAsStringSync());
  if (keyBase64 == null) {
    print('invalid key file');
    exit(65);
  }
  await secrets.write(SecretKeys.backupAesKey, keyBase64);

  final ImportResult result;
  try {
    result = await service.importFromString(contents);
  } on Object catch (e) {
    print('import failed: ${e.runtimeType}');
    exit(70);
  }

  print(
    'format: ${result.format.name} - keys restored: '
    '${result.keysRestored}',
  );
  print(
    'username restored: '
    '${await secrets.read(SecretKeys.username) != null}',
  );

  // What actually arrived? Counts only.
  final mutex = PrefsMutex();
  final playlists = await PlaylistsStore(store: store, mutex: mutex).readAll();
  final tags = TagsIndex(store: store, mutex: mutex);
  final offline = await OfflineIndex(store: store, mutex: mutex).readAll();
  final artwork = await ArtworkIndex(store: store, mutex: mutex).readAll();
  final tagCounts = await tags.allTagsWithCounts();

  print(
    'saved playlists: ${playlists.length} '
    '(items: ${playlists.fold<int>(0, (n, p) => n + p.items.length)})',
  );
  print(
    'entries in the legacy path format: ${playlists.fold<int>(0, (n, p) => n + p.items.where((e) => e.isLegacy).length)}',
  );
  print(
    'tags: ${tagCounts.length} - tagged items: '
    '${(await tags.readAll()).length}',
  );
  print(
    'offline index: ${offline.length} - artwork index: '
    '${artwork.length}',
  );

  final keys = (await store.keys()).toList()..sort();
  print('all restored keys (${keys.length}): ${keys.join(', ')}');

  // The settings keys that matter; sensitive values are masked.
  for (final key in const [
    'server_url',
    'active_url',
    'local_url',
    'video_quality',
    'theme_mode',
    'app_locale',
  ]) {
    final value = await store.get(key);
    final shown = value == null
        ? '—'
        : (key.contains('url') ? '[URL:${value.toString().length}]' : value);
    print('  $key = $shown');
  }

  final externals = await store.getStringList('external_urls');
  if (externals != null) print('  external_urls = ${externals.length} urls');

  final positions = keys.where((k) => k.startsWith('playback_pos_')).length;
  print('resume positions: $positions');

  // Checks the playlists' JSON integrity after the restore.
  final raw = await store.getString(PlaylistsStore.prefsKey);
  if (raw != null) {
    final decoded = json.decode(raw);
    print('saved_playlists is a ${decoded.runtimeType}');
  }
  exit(0);
}
