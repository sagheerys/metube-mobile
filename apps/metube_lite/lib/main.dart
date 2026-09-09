import 'dart:async';

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
import 'features/downloads_library/local_item.dart';
import 'features/settings/settings_state.dart';
import 'features/shared/stores.dart';

/// Bootstrap only: storage, the settings snapshot, the background audio
/// player, runApp.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // **The app is portrait and only the player rotates** (decision
  // 2026-09-05). `MTRotationScope` releases this lock while the video
  // player is open.
  unawaited(MTOrientation.lockPortrait());
  initMTL10n();

  final prefs = await SharedPreferences.getInstance();
  final store = SharedPrefsKeyValueStore(prefs);
  const secrets = SecureSecretStore();
  final initialSettings = await LiteSettings.load(store, secrets);

  // One lock for all storage (rule 3), passed to everyone rather than
  // created twice. It was created above, before the seeding.
  final logsDir = await getApplicationSupportDirectory();
  final logger = MTLogger(filePath: '${logsDir.path}/logs/metube_lite.log');

  // One lock for all storage (rule 3), passed to everyone rather than
  // created twice.
  final mutex = PrefsMutex();
  // Lite never streams: the endpoint stays `none`, so the golden rule
  // always ends at the local file.
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

  // **Sweeping orphaned partials (defect خ-3):** killing the app mid-way
  // through a large pull leaves a `.part` nobody cleans, and the library
  // scan ignores it on purpose, so the space is lost unseen. We do not
  // await it: startup never waits on a cleanup.
  unawaited(logger.log('app started (lite)', tag: 'app'));

  // **Sweeping orphaned partials (defect خ-3):** killing the app mid-way
  // through a large pull leaves a `.part` nobody cleans, and the library
  // scan ignores it on purpose, so the space is lost unseen. We do not
  // await it: startup never waits on a cleanup.
  unawaited(
    sweepPartialFiles(
      liteMediaDir,
    ).then((count) => count == 0 ? null : logger.log('swept $count partials')),
  );

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
