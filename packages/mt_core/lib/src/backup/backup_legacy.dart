part of 'backup_service.dart';

/// **Legacy format paths**: the old Lite backup, plus shape migrations
/// inside the same keys. Read-only, for migration.
///
/// **A `part` file rather than its own library** (rule 4, the size limit):
/// it works on the service's own `store` and `mutex`.
extension BackupServiceLegacy on BackupService {
  /// The old Lite payload: flat settings plus JSON blocks, restored into
  /// the
  /// same legacy keys (§5.1 kept those names for exactly this).
  Future<ImportResult> _applyLegacyLite(Map<String, dynamic> payload) async {
    var restored = 0;
    final settings = (payload['settings'] as Map?) ?? const {};
    await mutex.run(() async {
      Future<void> putString(String key, String? value) async {
        if (value == null || value.isEmpty) return;
        await store.setString(key, value);
        restored++;
      }

      await putString('server_url', settings['serverUrl']?.toString());
      final quality = settings['videoQuality']?.toString();
      await putString(
        'video_quality',
        MTConstants.qualityWireValues.contains(quality) ? quality : 'best',
      );
      await putString('theme_mode', settings['themeMode']?.toString());
      await putString('app_locale', settings['locale']?.toString());
      if (settings['playMode'] is num) {
        await store.setInt(
          'player_play_mode',
          (settings['playMode'] as num).toInt(),
        );
        restored++;
      }
      for (final MapEntry(:key, :value) in {
        'video_title_metadata': payload['videoMetadata'],
        'video_playback_positions': payload['playbackPositions'],
        'saved_playlists': payload['savedPlaylists'],
      }.entries) {
        if (value != null) {
          await store.setString(key, json.encode(value));
          restored++;
        }
      }
      // The same shape migration applied to `MTSBACKUP1`. The old Lite
      // stored
      // positions as **seconds in a string** and `playMode` as a number
      // (confirmed against a real backup 2026-09-01: 32 positions imported
      // dead
      // without this line).
      await _migrateLegacyShapes();
    });
    await _restoreUsername(settings['username']?.toString());
    return ImportResult(
      format: BackupFormat.legacyLite,
      keysRestored: restored,
    );
  }

  /// **Legacy shape migrations inside the same keys** (confirmed against a
  /// real backup 2026-09-01). They run **inside the lock**, after the cells
  /// are applied:
  /// - `video_playback_positions`: a url-to-seconds string map becomes
  ///   `playback_pos_<url>` keys in milliseconds (§5.1); without it, resume
  ///   positions were lost.
  /// - `player_play_mode`: it used to be a number, an old enum index,
  ///   while the new reader expects a string, so it is removed and falls
  ///   back to the default instead of holding a dead value.
  Future<void> _migrateLegacyShapes() async {
    await _migratePlaybackPositions();
    for (final key in await store.keys()) {
      if (key == 'player_play_mode' || key.startsWith('player_play_mode_')) {
        if (await store.get(key) is int) await store.remove(key);
      }
    }
  }

  Future<void> _migratePlaybackPositions() async {
    const legacyKey = 'video_playback_positions';
    final raw = await store.getString(legacyKey);
    if (raw == null || raw.isEmpty) return;
    final Object? decoded;
    try {
      decoded = json.decode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    for (final entry in decoded.entries) {
      final url = entry.key.toString();
      final value = num.tryParse(entry.value.toString());
      if (url.isEmpty || value == null || value <= 0) continue;
      // The old format stored **seconds**; any value larger than a day in
      // seconds was already in milliseconds.
      final ms = value > BackupService._secondsInDay
          ? value.toInt()
          : (value * 1000).toInt();
      await store.setInt('${BackupService._positionPrefix}$url', ms);
    }
    await store.remove(legacyKey);
  }
}
