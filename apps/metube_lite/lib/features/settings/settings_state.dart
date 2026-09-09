import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';

/// Lite's settings state: **one** server URL, with no automatic switching,
/// which is a Super feature. Storage key names follow `05-DATA-SCHEMA.md`
/// §5.1 exactly, and they are the same names the old Lite used, so its
/// backup restores as it is.
class LiteSettings {
  const LiteSettings({
    this.serverUrl = '',
    this.username,
    this.password,
    this.quality = Quality.best,
    this.quickDownload = false,
    this.wifiOnly = false,
    this.autoRetry = true,
    this.compatiblePlayback = true,
    this.themeMode = ThemeMode.system,
    this.localeCode,
  });

  final String serverUrl;
  final String? username;
  final String? password;
  final Quality quality;

  /// **Quick download**: a shared or pasted link downloads immediately at
  /// the default quality with no sheet, which makes that an effective
  /// setting rather than an initial value.
  final bool quickDownload;

  /// Pulling to the device on Wi-Fi only, which matters more in the family
  /// edition than anywhere else.
  final bool wifiOnly;

  /// Retries what failed because of the network once it returns, never what
  /// the server refused.
  final bool autoRetry;

  /// **Best playback compatibility (H.264/AAC)**, from field report
  /// 2026-09-03. Measured against a real server: `quality:best` alone
  /// yields VP9 or AV1 in webm, and hardware AV1 decoding is missing from
  /// most phones, so the picture appears torn. On by default; turning it
  /// off allows the highest resolution at the cost of compatibility.
  final bool compatiblePlayback;
  final ThemeMode themeMode;

  /// null means the system language (detected on first run).
  final String? localeCode;

  bool get isConfigured => serverUrl.trim().isNotEmpty;

  ServerConfig? get serverConfig => isConfigured
      ? ServerConfig(baseUrl: serverUrl, username: username, password: password)
      : null;

  LiteSettings copyWith({
    String? serverUrl,
    String? username,
    String? password,
    Quality? quality,
    bool? quickDownload,
    bool? wifiOnly,
    bool? autoRetry,
    bool? compatiblePlayback,
    ThemeMode? themeMode,
    String? localeCode,

    /// Distinguishes "clear the language" from "do not change it": `null`
    /// alone is not enough.
    bool clearLocale = false,
  }) => LiteSettings(
    serverUrl: serverUrl ?? this.serverUrl,
    username: username ?? this.username,
    password: password ?? this.password,
    quality: quality ?? this.quality,
    quickDownload: quickDownload ?? this.quickDownload,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    autoRetry: autoRetry ?? this.autoRetry,
    compatiblePlayback: compatiblePlayback ?? this.compatiblePlayback,
    themeMode: themeMode ?? this.themeMode,
    localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
  );

  /// Loads the initial snapshot before runApp.
  static Future<LiteSettings> load(
    KeyValueStore store,
    SecretStore secrets,
  ) async {
    final themeName = await store.getString('theme_mode');
    return LiteSettings(
      serverUrl: await store.getString('server_url') ?? '',
      username: await secrets.read(SecretKeys.username),
      password: await secrets.read(SecretKeys.password),
      quality: Quality.fromWire(await store.getString('video_quality')),
      quickDownload: await store.getBool('quick_download_enabled') ?? false,
      wifiOnly: await store.getBool('wifi_only_downloads') ?? false,
      autoRetry: await store.getBool('auto_retry_downloads') ?? true,
      compatiblePlayback: await store.getBool('compatible_playback') ?? true,
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

  /// Re-reads every setting from storage, after importing a backup (rule
  /// 8).
  Future<void> reloadFromStore() async =>
      state = await LiteSettings.load(_store, _secrets);

  /// Rule 1: test the connection, then save. **A broken setting is never
  /// saved silently.** Throws a classified [MTApiException] for the UI to
  /// display.
  Future<void> saveServer({
    required String url,
    String? username,
    String? password,
  }) async {
    final config = ServerConfig(
      baseUrl: url,
      username: username,
      password: password,
    );
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

  Future<void> setCompatiblePlayback(bool enabled) async {
    await _mutex.run(() => _store.setBool('compatible_playback', enabled));
    state = state.copyWith(compatiblePlayback: enabled);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _mutex.run(() => _store.setString('theme_mode', mode.name));
    state = state.copyWith(themeMode: mode);
  }

  /// **`null` means "follow the system language"**: the key is erased so
  /// `localeCode` returns empty, as it was on the day of installation.
  /// Without this the option was **a door that closes and never opens**:
  /// the first touch of the switch pinned a language forever, with no way
  /// back short of clearing the app's data, and with it the library and the
  /// favourites.
  Future<void> setLocale(String? code) async {
    await _mutex.run(
      () => code == null
          ? _store.remove('app_locale')
          : _store.setString('app_locale', code),
    );
    state = state.copyWith(localeCode: code, clearLocale: code == null);
  }
}
