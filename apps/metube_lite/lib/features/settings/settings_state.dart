import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';

/// حالة إعدادات Lite — رابط سيرفر **واحد** (لا تبديل تلقائي: م-28 ميزة
/// Super). أسماء مفاتيح التخزين من `05-DATA-SCHEMA.md` §5.1 حرفياً،
/// وهي نفس أسماء Lite القديم فتُستعاد نسخته الاحتياطية كما هي.
class LiteSettings {
  const LiteSettings({
    this.serverUrl = '',
    this.username,
    this.password,
    this.quality = Quality.best,
    this.quickDownload = false,
    this.wifiOnly = false,
    this.autoRetry = true,
    this.themeMode = ThemeMode.system,
    this.localeCode,
  });

  final String serverUrl;
  final String? username;
  final String? password;
  final Quality quality;

  /// **التحميل السريع**: الرابط المشارَك/الملصوق ينزل فوراً بالجودة
  /// الافتراضية بلا ورقة — يجعلها إعداداً فاعلاً لا قيمة مبدئية.
  final bool quickDownload;

  /// السحب إلى الجهاز على Wi‑Fi فقط — يهمّ نسخة العائلة أكثر من غيرها.
  final bool wifiOnly;

  /// إعادة ما فشل بسبب الشبكة عند عودتها (لا ما رفضه الخادم).
  final bool autoRetry;
  final ThemeMode themeMode;

  /// null = لغة النظام (كشف أول تشغيل — م-30).
  final String? localeCode;

  bool get isConfigured => serverUrl.trim().isNotEmpty;

  ServerConfig? get serverConfig => isConfigured
      ? ServerConfig(
          baseUrl: serverUrl, username: username, password: password)
      : null;

  LiteSettings copyWith({
    String? serverUrl,
    String? username,
    String? password,
    Quality? quality,
    bool? quickDownload,
    bool? wifiOnly,
    bool? autoRetry,
    ThemeMode? themeMode,
    String? localeCode,
  }) =>
      LiteSettings(
        serverUrl: serverUrl ?? this.serverUrl,
        username: username ?? this.username,
        password: password ?? this.password,
        quality: quality ?? this.quality,
        quickDownload: quickDownload ?? this.quickDownload,
        wifiOnly: wifiOnly ?? this.wifiOnly,
        autoRetry: autoRetry ?? this.autoRetry,
        themeMode: themeMode ?? this.themeMode,
        localeCode: localeCode ?? this.localeCode,
      );

  /// تحميل اللقطة الأولية قبل runApp.
  static Future<LiteSettings> load(
      KeyValueStore store, SecretStore secrets) async {
    final themeName = await store.getString('theme_mode');
    return LiteSettings(
      serverUrl: await store.getString('server_url') ?? '',
      username: await secrets.read(SecretKeys.username),
      password: await secrets.read(SecretKeys.password),
      quality: Quality.fromWire(await store.getString('video_quality')),
      quickDownload: await store.getBool('quick_download_enabled') ?? false,
      wifiOnly: await store.getBool('wifi_only_downloads') ?? false,
      autoRetry: await store.getBool('auto_retry_downloads') ?? true,
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      localeCode: await store.getString('app_locale'),
    );
  }
}

class SettingsNotifier extends Notifier<LiteSettings> {
  @override
  LiteSettings build() => ref.read(initialSettingsProvider);

  KeyValueStore get _store => ref.read(keyValueStoreProvider);
  SecretStore get _secrets => ref.read(secretStoreProvider);
  PrefsMutex get _mutex => ref.read(prefsMutexProvider);

  /// إعادة قراءة كل الإعدادات من التخزين — بعد استيراد نسخة (ر-8).
  Future<void> reloadFromStore() async =>
      state = await LiteSettings.load(_store, _secrets);

  /// ر-1: اختبار الاتصال ثم الحفظ — **لا حفظ صامت لإعداد فاسد**.
  /// يرمي [MTApiException] مصنفاً ليعرضه UI.
  Future<void> saveServer({
    required String url,
    String? username,
    String? password,
  }) async {
    final config = ServerConfig(
        baseUrl: url, username: username, password: password);
    final client = MeTubeApiClient(config: config);
    try {
      await client.testConnection();
    } finally {
      client.close();
    }
    await _mutex.run(() => _store.setString('server_url', config.baseUrl));
    await _writeSecret(SecretKeys.username, username);
    await _writeSecret(SecretKeys.password, password);
    state = state.copyWith(
      serverUrl: config.baseUrl,
      username: username,
      password: password,
    );
  }

  Future<void> _writeSecret(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _secrets.delete(key);
    } else {
      await _secrets.write(key, value);
    }
  }

  Future<void> setQuality(Quality quality) async {
    await _mutex.run(() => _store.setString('video_quality', quality.wire));
    state = state.copyWith(quality: quality);
  }

  Future<void> setQuickDownload(bool enabled) async {
    await _mutex.run(() => _store.setBool('quick_download_enabled', enabled));
    state = state.copyWith(quickDownload: enabled);
  }

  Future<void> setWifiOnly(bool enabled) async {
    await _mutex.run(() => _store.setBool('wifi_only_downloads', enabled));
    state = state.copyWith(wifiOnly: enabled);
  }

  Future<void> setAutoRetry(bool enabled) async {
    await _mutex.run(() => _store.setBool('auto_retry_downloads', enabled));
    state = state.copyWith(autoRetry: enabled);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _mutex.run(() => _store.setString('theme_mode', mode.name));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setLocale(String code) async {
    await _mutex.run(() => _store.setString('app_locale', code));
    state = state.copyWith(localeCode: code);
  }
}
