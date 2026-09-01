import 'dart:convert';

import '../constants/mt_constants.dart';
import '../storage/key_value_store.dart';
import '../storage/secret_store.dart';
import 'backup_crypto.dart';

enum BackupFormat { v2, legacyLite, legacySuper }

class ImportResult {
  const ImportResult({required this.format, required this.keysRestored});
  final BackupFormat format;
  final int keysRestored;
}

/// خدمة النسخ الاحتياطي (§5.4): كتابة v2 `MTF1` وقراءة التنسيقات الثلاثة
/// (القديمان **قراءة فقط** للهجرة). الحمولة: كل مفاتيح §5.1 + `username`
/// — **كلمة المرور لا تدخل أبداً**. تعمل على نصوص؛ ملفات القرص شأن التطبيق.
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

  /// `lite` أو `super` — للتوثيق داخل الملف فقط؛ الاستيراد يقبل الكل.
  final String variant;

  Future<String> _getOrCreateKey() async {
    final stored = await secrets.read(SecretKeys.backupAesKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final key = BackupCrypto.generateKeyBase64();
    await secrets.write(SecretKeys.backupAesKey, key);
    return key;
  }

  /// تصدير v2 مشفراً — لقطة كاملة تحت القفل كي لا يمزقها كاتب متزامن.
  Future<String> exportToString() => mutex.run(() async {
        final prefsMap = <String, dynamic>{};
        for (final key in await store.keys()) {
          final cell = _encodeCell(await store.get(key));
          if (cell != null) prefsMap[key] = cell;
        }
        final username = await secrets.read(SecretKeys.username);
        final payload = json.encode({
          'app': 'MTF',
          'variant': variant,
          'version': 2,
          'backupDate': DateTime.now().toIso8601String(),
          'prefs': prefsMap,
          'secure': {'username': ?username},
        });
        return BackupCrypto.encrypt(
          plaintext: payload,
          keyBase64: await _getOrCreateKey(),
        );
      });

  /// استيراد أي تنسيق من الثلاثة — التمييز بالترويسة قبل أي فك.
  Future<ImportResult> importFromString(String contents) async {
    final header = BackupCrypto.headerOf(contents);
    if (header == null) throw const BackupFormatException('unknown header');
    final plaintext = BackupCrypto.decrypt(
      contents: contents,
      keyBase64: await _getOrCreateKey(),
    );
    final decoded = json.decode(plaintext);
    if (decoded is! Map) throw const BackupFormatException('not a map');
    final payload = Map<String, dynamic>.from(decoded);

    return switch (header) {
      BackupCrypto.headerLegacyLite => _applyLegacyLite(payload),
      // v2 وMTSBACKUP1 بنفس بنية prefs المصنفة.
      _ => _applyTypedPrefs(
          payload,
          header == BackupCrypto.headerV2
              ? BackupFormat.v2
              : BackupFormat.legacySuper,
        ),
    };
  }

  Future<ImportResult> _applyTypedPrefs(
      Map<String, dynamic> payload, BackupFormat format) async {
    final prefs = (payload['prefs'] as Map?) ?? const {};
    var restored = 0;
    await mutex.run(() async {
      for (final entry in prefs.entries) {
        if (await _applyCell(entry.key.toString(), entry.value)) restored++;
      }
      if (format != BackupFormat.v2) await _migrateLegacyShapes();
    });
    await _restoreUsername(
        ((payload['secure'] as Map?) ?? const {})['username']?.toString() ??
            (payload['settings'] as Map?)?['username']?.toString());
    return ImportResult(format: format, keysRestored: restored);
  }

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
      final ms = value > _secondsInDay ? value.toInt() : (value * 1000).toInt();
      await store.setInt('$_positionPrefix$url', ms);
    }
    await store.remove(legacyKey);
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

  // ── مفتاح التشفير: تصدير/استيراد للاستعادة على جهاز آخر ──

  Future<String> exportKeyFile() async =>
      BackupCrypto.encodeKeyFile(await _getOrCreateKey());

  /// استيراد مفتاح (بأي ترويسة معروفة) — يستبدل مفتاح الجهاز؛ يُستدعى
  /// **قبل** استيراد نسخة من جهاز آخر. false = ملف غير صالح.
  Future<bool> importKeyFile(String contents) async {
    final keyBase64 = BackupCrypto.decodeKeyFile(contents);
    if (keyBase64 == null) return false;
    await secrets.write(SecretKeys.backupAesKey, keyBase64);
    return true;
  }
}
