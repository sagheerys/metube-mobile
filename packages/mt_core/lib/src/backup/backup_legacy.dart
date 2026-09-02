part of 'backup_service.dart';

/// **مسارات التنسيقات القديمة** (Lite القديم + هجرة الأشكال داخل نفس
/// المفاتيح) — قراءة فقط للهجرة.
///
/// **ملف `part` لا مكتبة مستقلة** (القاعدة 4 — حدّ الأسطر): يعمل على
/// `store` و`mutex` الخاصين بالخدمة.
extension BackupServiceLegacy on BackupService {
  /// حمولة Lite القديمة: settings مسطحة + كتل JSON — تُعاد للمفاتيح
  /// القديمة نفسها (§5.1: الأسماء القديمة أُبقيت لهذا الغرض).
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
            'player_play_mode', (settings['playMode'] as num).toInt());
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
      // نفس هجرة الأشكال المطبقة على `MTSBACKUP1` — Lite القديم يخزّن
      // المواضع **ثوانٍ نصاً** و`playMode` رقماً (مُثبت على نسخة المالك
      // الحقيقية 2026-09-01: 32 موضعاً كانت تُستورد ميتة بلا هذا السطر).
      await _migrateLegacyShapes();
    });
    await _restoreUsername(settings['username']?.toString());
    return ImportResult(
        format: BackupFormat.legacyLite, keysRestored: restored);
  }

  /// **هجرة أشكال قديمة داخل نفس المفاتيح** (مُثبتة على نسخة المالك
  /// الحقيقية 2026-09-01) — تُنفَّذ **داخل القفل** بعد تطبيق الخلايا:
  /// - `video_playback_positions`: خريطة رابط→ثوانٍ نصاً ⇒ مفاتيح
  ///   `playback_pos_<url>` بالميلي (§5.1)، وإلا ضاعت مواضع الاستئناف.
  /// - `player_play_mode`: كان رقماً (فهرس enum قديم) والقارئ الجديد
  ///   ينتظر نصاً ⇒ يُزال ليعود للافتراضي بدل قيمة ميتة.
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
      // القديم يخزّن **ثوانٍ**؛ أي قيمة تتجاوز يوماً بالثواني هي ميلي أصلاً.
      final ms = value > BackupService._secondsInDay ? value.toInt() : (value * 1000).toInt();
      await store.setInt('${BackupService._positionPrefix}$url', ms);
    }
    await store.remove(legacyKey);
  }
}
