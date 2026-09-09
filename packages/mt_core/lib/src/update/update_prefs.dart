import '../storage/key_value_store.dart';

/// Self-update preferences, with keys from `05-DATA-SCHEMA.md` §5.1.
///
/// **A store of its own rather than fields in `SuperSettings` or
/// `LiteSettings`**: the feature arrives behind a new path, so it touches
/// neither settings loading nor settings saving (rule 5).
class UpdatePrefs {
  UpdatePrefs({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const String autoCheckKey = 'update_auto_check';
  static const String lastCheckKey = 'update_last_check';
  static const String skippedVersionKey = 'update_skipped_version';

  /// The version of the downloaded file sitting in the cache. Wiped once
  /// the
  /// app is that version.
  static const String downloadedVersionKey = 'update_downloaded_version';

  /// **On by default**: whoever never opens settings is exactly who needs
  /// updates most.
  Future<bool> autoCheck() async =>
      await store.getBool(autoCheckKey) ?? true;

  Future<void> setAutoCheck(bool value) =>
      mutex.run(() => store.setBool(autoCheckKey, value));

  Future<DateTime?> lastCheck() async {
    final ms = await store.getInt(lastCheckKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Stamped **after every attempt**, successful or not: a private
  /// repository or a dead network must not repeat the request at every
  /// launch.
  Future<void> markChecked(DateTime when) =>
      mutex.run(() => store.setInt(lastCheckKey, when.millisecondsSinceEpoch));

  Future<String?> skippedVersion() => store.getString(skippedVersionKey);

  Future<void> skipVersion(String version) =>
      mutex.run(() => store.setString(skippedVersionKey, version));

  /// Called after a successful install, or an old skip would keep muting a
  /// later release if version numbers ever moved backwards.
  Future<void> clearSkip() => mutex.run(() => store.remove(skippedVersionKey));

  Future<String?> downloadedVersion() => store.getString(downloadedVersionKey);

  Future<void> setDownloadedVersion(String version) =>
      mutex.run(() => store.setString(downloadedVersionKey, version));

  Future<void> clearDownloaded() =>
      mutex.run(() => store.remove(downloadedVersionKey));
}
