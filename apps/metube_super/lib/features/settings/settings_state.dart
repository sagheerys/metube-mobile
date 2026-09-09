import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';

/// Super's settings state: loaded once at startup and managed here alone.
/// Storage key names follow `05-DATA-SCHEMA.md` §5.1 exactly.
class SuperSettings {
  const SuperSettings({
    this.localUrl = '',
    this.externalUrls = const [],
    this.activeUrl,
    this.autoSwitch = true,
    this.username,
    this.password,
    this.quality = Quality.best,
    this.quickDownload = false,
    this.wifiOnly = false,
    this.saveBatchToDevice = false,
    this.autoRetry = true,
    this.compatiblePlayback = true,
    this.themeMode = ThemeMode.system,
    this.localeCode,
  });

  final String localUrl;
  final List<String> externalUrls;

  /// The currently adopted endpoint, from the last manual choice or
  /// automatic switch.
  final String? activeUrl;
  final bool autoSwitch;
  final String? username;
  final String? password;
  final Quality quality;

  /// **Quick download**: a shared or pasted link downloads immediately at
  /// the default quality with no sheet. It makes "default quality" an
  /// effective setting rather than an initial value in a dialog the user
  /// re-chooses every time.
  final bool quickDownload;

  /// Pulling to the device on Wi-Fi only; adding to the server stays
  /// available always.
  final bool wifiOnly;

  /// **A playlist batch is saved to the device as well** (requested
  /// 2026-09-03). Super adds to the server and does not pull (rule 2); this
  /// applies "available offline" automatically to every batch member that
  /// completes, and the original stays on the server.
  final bool saveBatchToDevice;

  /// Retries what failed because of the network once it returns, never what
  /// the server refused.
  final bool autoRetry;

  /// **Best playback compatibility (H.264/AAC)**, from field report
  /// 2026-09-03. Measured against a real server: the "best" quality alone
  /// yields VP9 or AV1 in webm, and hardware AV1 decoding is missing from
  /// most phones, so the picture appears torn. On by default; turning it
  /// off allows the highest resolution at the cost of compatibility.
  final bool compatiblePlayback;
  final ThemeMode themeMode;

  /// null means the system language (detected on first run).
  final String? localeCode;

  bool get isConfigured => (activeUrl ?? '').trim().isNotEmpty;

  ServerConfig? get serverConfig => isConfigured
      ? ServerConfig(
          baseUrl: activeUrl!,
          username: username,
          password: password,
        )
      : null;

  /// Every candidate in preference order, local first (rule 9).
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
    bool? quickDownload,
    bool? wifiOnly,
    bool? saveBatchToDevice,
    bool? autoRetry,
    bool? compatiblePlayback,
    ThemeMode? themeMode,
    String? localeCode,
    bool clearCredentials = false,

    /// Distinguishes "clear the language" from "do not change it": `null`
    /// alone is not enough.
    bool clearLocale = false,
  }) => SuperSettings(
    localUrl: localUrl ?? this.localUrl,
    externalUrls: externalUrls ?? this.externalUrls,
    activeUrl: activeUrl ?? this.activeUrl,
    autoSwitch: autoSwitch ?? this.autoSwitch,
    username: clearCredentials ? null : (username ?? this.username),
    password: clearCredentials ? null : (password ?? this.password),
    quality: quality ?? this.quality,
    quickDownload: quickDownload ?? this.quickDownload,
    wifiOnly: wifiOnly ?? this.wifiOnly,
    saveBatchToDevice: saveBatchToDevice ?? this.saveBatchToDevice,
    autoRetry: autoRetry ?? this.autoRetry,
    compatiblePlayback: compatiblePlayback ?? this.compatiblePlayback,
    themeMode: themeMode ?? this.themeMode,
    localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
  );

  /// Loads the initial snapshot before runApp.
  static Future<SuperSettings> load(
    KeyValueStore store,
    SecretStore secrets,
  ) async {
    final themeName = await store.getString('theme_mode');
    return SuperSettings(
      localUrl: await store.getString('local_url') ?? '',
      externalUrls: await store.getStringList('external_urls') ?? const [],
      activeUrl:
          await store.getString('active_url') ??
          await store.getString('server_url'),
      autoSwitch: await store.getBool('auto_switch_enabled') ?? true,
      username: await secrets.read(SecretKeys.username),
      password: await secrets.read(SecretKeys.password),
      quality: Quality.fromWire(await store.getString('video_quality')),
      quickDownload: await store.getBool('quick_download_enabled') ?? false,
      wifiOnly: await store.getBool('wifi_only_downloads') ?? false,
      saveBatchToDevice: await store.getBool('batch_save_to_device') ?? false,
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

class SettingsNotifier extends Notifier<SuperSettings> {
  @override
  SuperSettings build() => ref.read(initialSettingsProvider);

  KeyValueStore get _store => ref.read(keyValueStoreProvider);
  SecretStore get _secrets => ref.read(secretStoreProvider);
  PrefsMutex get _mutex => ref.read(prefsMutexProvider);

  /// Re-reads every setting from storage, after importing a backup (rule
  /// 8).
  Future<void> reloadFromStore() async =>
      state = await SuperSettings.load(_store, _secrets);

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

  Future<void> setQuickDownload(bool enabled) async {
    await _mutex.run(() => _store.setBool('quick_download_enabled', enabled));
    state = state.copyWith(quickDownload: enabled);
  }

  Future<void> setWifiOnly(bool enabled) async {
    await _mutex.run(() => _store.setBool('wifi_only_downloads', enabled));
    state = state.copyWith(wifiOnly: enabled);
  }

  Future<void> setSaveBatchToDevice(bool enabled) async {
    await _mutex.run(() => _store.setBool('batch_save_to_device', enabled));
    state = state.copyWith(saveBatchToDevice: enabled);
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

  // Networking (endpoint switching).

  Future<void> setLocalUrl(String url) async {
    final normalized = url.trim().isEmpty
        ? ''
        : ServerConfig.normalizeBaseUrl(url);
    await _mutex.run(() => _store.setString('local_url', normalized));
    state = state.copyWith(localUrl: normalized);
  }

  Future<void> addExternalUrl(String url) async {
    final normalized = ServerConfig.normalizeBaseUrl(url);
    if (normalized.isEmpty || state.externalUrls.contains(normalized)) return;
    await _saveExternal([...state.externalUrls, normalized]);
  }

  Future<void> removeExternalUrl(String url) async {
    await _saveExternal(state.externalUrls.where((u) => u != url).toList());
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

  /// Adopts a responding endpoint, manually or from the automatic switch,
  /// silently (rule 9).
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
