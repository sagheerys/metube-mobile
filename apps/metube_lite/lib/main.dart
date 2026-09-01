import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'di.dart';
import 'features/settings/settings_state.dart';
import 'features/shared/stores.dart';

/// bootstrap فقط: التخزين، لقطة الإعدادات، مشغل الصوت الخلفي، runApp.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initMTL10n();

  final prefs = await SharedPreferences.getInstance();
  final store = SharedPrefsKeyValueStore(prefs);
  const secrets = SecureSecretStore();
  final initialSettings = await LiteSettings.load(store, secrets);

  // السجل الحلقي (م-32) في مساحة التطبيق الخاصة (§5.3).
  final logsDir = await getApplicationSupportDirectory();
  final logger = MTLogger(filePath: '${logsDir.path}/logs/metube_lite.log');

  // قفل واحد لكل التخزين (القاعدة 3) — يُمرَّر للجميع لا يُنشأ مرتين.
  final mutex = PrefsMutex();
  // Lite لا يبث: المنفذ يبقى `none` فتنتهي القاعدة الذهبية للملف المحلي.
  final resolver = PlaybackSourceResolver(endpoint: ServerStreamEndpoint.none);
  final handler = await AudioService.init(
    builder: () => MTAudioHandler(
      player: JustAudioPort(),
      resolver: resolver,
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.yasir.metubelite.audio',
      androidNotificationChannelName: 'MeTube Lite',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  await handler.loadPreferences();

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(secrets),
        prefsMutexProvider.overrideWithValue(mutex),
        initialSettingsProvider.overrideWithValue(initialSettings),
        playbackResolverProvider.overrideWithValue(resolver),
        audioHandlerProvider.overrideWithValue(handler),
        loggerProvider.overrideWithValue(logger),
      ],
      child: const LiteApp(),
    ),
  );
}
