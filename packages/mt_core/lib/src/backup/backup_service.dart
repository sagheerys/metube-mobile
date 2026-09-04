import 'dart:convert';

import '../constants/mt_constants.dart';
import '../storage/key_value_store.dart';
import '../storage/secret_store.dart';
import 'backup_crypto.dart';

part 'backup_legacy.dart';

/// `plain` هي الصيغة المكتوبة اليوم؛ الثلاث الباقية **قراءة فقط**
/// (هجرة من إصدارات سابقة).
enum BackupFormat { plain, v2, legacyLite, legacySuper }

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

  /// مفاتيح تحمل روابط سيرفر قد تُلصق بصيغة `https://user:pass@host`.
  static const _urlKeys = {
    'server_url',
    'local_url',
    'active_url',
    'external_urls',
  };

  /// **حذف الاعتمادات المضمّنة في الرابط قبل النسخ (إصلاح خ-2).**
  /// استثناء كلمة السر من النسخة صحيح، لكن من يلصق
  /// `https://user:pass@host` كرابط سيرفر يضعها في مفتاح نصي عادي —
  /// فتدخل النسخة الاحتياطية رغم القاعدة.
  static Object? _sanitize(String key, Object? value) {
    if (!_urlKeys.contains(key)) return value;
    if (value is String) return stripUrlCredentials(value);
    if (value is List) {
      return [for (final v in value) stripUrlCredentials(v.toString())];
    }
    return value;
  }

  /// يعيد الرابط بلا `user:pass@` — وغير الروابط كما هي.
  static String stripUrlCredentials(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.userInfo.isEmpty) return raw;
    return uri.replace(userInfo: '').toString();
  }

  /// مفتاح فكّ النسخ القديمة **إن وُجد** — لا يُولَّد.
  ///
  /// كان يُولِّد مفتاحاً حين لا يجد، وهذا صحيح يوم كانت الكتابة مشفّرة.
  /// بعد إزالة التشفير (2026-09-04) صار التوليد عبثاً محضاً: مفتاح جديد
  /// لن يفكّ شيئاً، ثم يفشل الفكّ برسالة أبعد عن السبب. الغياب نفسه هو
  /// الجواب: [BackupKeyMismatchException].
  Future<String> _decryptionKey() async {
    final stored = await secrets.read(SecretKeys.backupAesKey);
    if (stored == null || stored.isEmpty) {
      throw const BackupKeyMismatchException();
    }
    return stored;
  }

  /// **تصدير نصّي غير مشفَّر — وبلا أي سرّ** (قرار المالك 2026-09-04).
  ///
  /// كان `MTF1` مشفَّراً بمفتاح يعيش في التخزين الآمن، فيموت مع «مسح
  /// البيانات» أو إعادة التثبيت — تاركاً نسخةً **يتيمة** لا تُفتح إلا
  /// إن كان المستخدم صدّر المفتاح، وهو ما لا يفعله أحد. والمحتوى نفسه
  /// (روابط، عناوين، قوائم، وسوم) يراه من يفتح التطبيق أصلاً.
  ///
  /// و[SecretKeys.username] **لم يعد يُنسخ**: كلمة المرور لم تكن تُنسخ
  /// أبداً، فالمستخدم يعيد إدخالها على كل حال — واسمٌ بلا كلمة لا يفتح
  /// شيئاً، فإخراجه يجعل الملف بلا سرّ إطلاقاً.
  ///
  /// لقطة كاملة تحت القفل كي لا يمزقها كاتب متزامن. مُنسَّقة بمسافات
  /// بادئة: ملفٌ غير مشفَّر يُقرأ بالعين مخرجٌ إنساني بلا كلفة.
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

  /// استيراد أي تنسيق: النصّي الجديد أو الثلاثة المشفّرة القديمة.
  ///
  /// **الترويسة تُفحص أولاً** (قاعدة §5.4: لا `json.decode` لملف مشفَّر
  /// قبل فكّه)، وغيابها مع بداية `{` يعني الصيغة النصّية.
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
      // v2 وMTSBACKUP1 بنفس بنية prefs المصنفة.
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
        Map<String, dynamic>.from(decoded), BackupFormat.plain);
  }

  Future<ImportResult> _applyTypedPrefs(
      Map<String, dynamic> payload, BackupFormat format) async {
    final prefs = (payload['prefs'] as Map?) ?? const {};
    var restored = 0;
    await mutex.run(() async {
      // **استعادة كل-أو-لا-شيء (إصلاح خ-2).** فشلٌ في المفتاح 40 من 200
      // كان يترك **جهازاً هجيناً**: فهرس دون-اتصال من جهاز آخر بعناوين
      // مفقودة، بلا أي تراجع ولا رسالة تقول أين توقف.
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
            (payload['settings'] as Map?)?['username']?.toString());
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

  /// إعادة قيمة كما كانت — للتراجع عن استعادة فشلت في منتصفها.
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
