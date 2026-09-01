import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';

/// حالة إعدادات Super — تُحمَّل مرة عند الإقلاع ثم تُدار هنا حصراً.
/// أسماء مفاتيح التخزين من `05-DATA-SCHEMA.md` §5.1 حرفياً.
class SuperSettings {
  const SuperSettings({
    this.localUrl = '',
    this.externalUrls = const [],
    this.activeUrl,
    this.autoSwitch = true,
    this.username,
    this.password,
    this.quality = Quality.best,
    this.themeMode = ThemeMode.system,
    this.localeCode,
  });

  final String localUrl;
  final List<String> externalUrls;

  /// الرابط المعتمد حالياً (نتيجة آخر اختيار يدوي أو تبديل تلقائي).
  final String? activeUrl;
  final bool autoSwitch;
  final String? username;
  final String? password;
  final Quality quality;
  final ThemeMode themeMode;

  /// null = لغة النظام (كشف أول تشغيل — م-30).
  final String? localeCode;

  bool get isConfigured => (activeUrl ?? '').trim().isNotEmpty;

  ServerConfig? get serverConfig => isConfigured
      ? ServerConfig(
          baseUrl: activeUrl!, username: username, password: password)
      : null;

  /// كل المرشحين بترتيب الأفضلية (المحلي أولاً — ر-9).
  List<String> get candidateUrls => [
        if (localUrl.trim().isNotEmpty) localUrl,
        ...externalUrls.where((u) => u.trim().isNotEmpty),
      ];

  SuperSettings copyWith({
    String? localUrl,
    List<String>? externalUrls,
    String? activeUrl,
    bool? autoSwitch,
    String? username,
    String? password,
    Quality? quality,
    ThemeMode? themeMode,
    String? localeCode,
    bool clearCredentials = false,
  }) =>
      SuperSettings(
        localUrl: localUrl ?? this.localUrl,
        externalUrls: externalUrls ?? this.externalUrls,
        activeUrl: activeUrl ?? this.activeUrl,
        autoSwitch: autoSwitch ?? this.autoSwitch,
        username: clearCredentials ? null : (username ?? this.username),
        password: clearCredentials ? null : (password ?? this.password),
        quality: quality ?? this.quality,
        themeMode: themeMode ?? this.themeMode,
        localeCode: localeCode ?? this.localeCode,
      );

  /// تحميل اللقطة الأولية قبل runApp.
  static Future<SuperSettings> load(
      KeyValueStore store, SecretStore secrets) async {
    final themeName = await store.getString('theme_mode');
    return SuperSettings(
      localUrl: await store.getString('local_url') ?? '',
      externalUrls: await store.getStringList('external_urls') ?? const [],
      activeUrl: await store.getString('active_url') ??
          await store.getString('server_url'),
      autoSwitch: await store.getBool('auto_switch_enabled') ?? true,
      username: await secrets.read(SecretKeys.username),
      password: await secrets.read(SecretKeys.password),
      quality: Quality.fromWire(await store.getString('video_quality')),
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      localeCode: await store.getString('app_locale'),
    );
  }
}

class SettingsNotifier extends Notifier<SuperSettings> {
  @override
  SuperSettings build() => ref.read(initialSettingsProvider);

  KeyValueStore get _store => ref.read(keyValueStoreProvider);
  SecretStore get _secrets => ref.read(secretStoreProvider);
  PrefsMutex get _mutex => ref.read(prefsMutexProvider);

  /// إعادة قراءة كل الإعدادات من التخزين — بعد استيراد نسخة (ر-8).
  Future<void> reloadFromStore() async =>
      state = await SuperSettings.load(_store, _secrets);

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
    await _mutex.run(() async {
      await _store.setString('server_url', config.baseUrl);
      await _store.setString('active_url', config.baseUrl);
    });
    await _writeSecret(SecretKeys.username, username);
    await _writeSecret(SecretKeys.password, password);
    state = state.copyWith(
      activeUrl: config.baseUrl,
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

  Future<void> setThemeMode(ThemeMode mode) async {
    await _mutex.run(() => _store.setString('theme_mode', mode.name));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setLocale(String code) async {
    await _mutex.run(() => _store.setString('app_locale', code));
    state = state.copyWith(localeCode: code);
  }

  // ── الشبكة (م-28 / ر-9) ──

  Future<void> setLocalUrl(String url) async {
    final normalized =
        url.trim().isEmpty ? '' : ServerConfig.normalizeBaseUrl(url);
    await _mutex.run(() => _store.setString('local_url', normalized));
    state = state.copyWith(localUrl: normalized);
  }

  Future<void> addExternalUrl(String url) async {
    final normalized = ServerConfig.normalizeBaseUrl(url);
    if (normalized.isEmpty || state.externalUrls.contains(normalized)) return;
    await _saveExternal([...state.externalUrls, normalized]);
  }

  Future<void> removeExternalUrl(String url) async {
    await _saveExternal(
        state.externalUrls.where((u) => u != url).toList());
  }

  Future<void> reorderExternalUrl(int oldIndex, int newIndex) async {
    final urls = List<String>.from(state.externalUrls);
    if (oldIndex < 0 || oldIndex >= urls.length) return;
    final url = urls.removeAt(oldIndex);
    urls.insert(newIndex.clamp(0, urls.length), url);
    await _saveExternal(urls);
  }

  Future<void> _saveExternal(List<String> urls) async {
    await _mutex.run(() => _store.setStringList('external_urls', urls));
    state = state.copyWith(externalUrls: urls);
  }

  Future<void> setAutoSwitch(bool enabled) async {
    await _mutex.run(() => _store.setBool('auto_switch_enabled', enabled));
    state = state.copyWith(autoSwitch: enabled);
  }

  /// اعتماد رابط مستجيب (يدوياً أو من التبديل التلقائي) — بصمت (ر-9).
  Future<void> adoptActiveUrl(String url) async {
    final normalized = ServerConfig.normalizeBaseUrl(url);
    if (normalized == state.activeUrl) return;
    await _mutex.run(() async {
      await _store.setString('active_url', normalized);
      await _store.setString('server_url', normalized);
    });
    state = state.copyWith(activeUrl: normalized);
  }
}
