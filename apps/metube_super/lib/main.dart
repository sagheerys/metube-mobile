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
import 'features/library/library_actions.dart';
import 'features/settings/auto_switch.dart';
import 'features/settings/settings_state.dart';
import 'features/shared/stores.dart';

/// bootstrap فقط: التخزين، لقطة الإعدادات، مشغل الصوت الخلفي، runApp.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // **التطبيق طولي والمشغل وحده يدور** (قرار المالك 2026-09-05) —
  // `MTRotationScope` يفكّ هذا القفل ما دام مشغل الفيديو مفتوحاً.
  unawaited(MTOrientation.lockPortrait());
  initMTL10n();

  final prefs = await SharedPreferences.getInstance();
  final store = SharedPrefsKeyValueStore(prefs);
  const secrets = SecureSecretStore();
  final mutex = PrefsMutex();
  var initialSettings = await SuperSettings.load(store, secrets);
  // م-28: التثبيت الذي هُيّئ برابط واحد يبقى بلا مرشحين للتبديل — نبذر
  // القائمة من الرابط المعتمد مرة واحدة قبل أول بناء.
  await seedEndpointsFromActive(store, mutex, initialSettings);
  initialSettings = await SuperSettings.load(store, secrets);

  // السجل الحلقي (م-32) في مساحة التطبيق الخاصة (§5.3).
  final logsDir = await getApplicationSupportDirectory();
  final logger = MTLogger(filePath: '${logsDir.path}/logs/metube_super.log');

  // قفل واحد لكل التخزين (القاعدة 3) — يُمرَّر للجميع لا يُنشأ مرتين
  // (أُنشئ أعلاه قبل البذر).
  final resolver = PlaybackSourceResolver(
    endpoint: ServerStreamEndpoint.none, // يضبطه playbackWiringProvider
  );
  final handler = await AudioService.init(
    builder: () => MTAudioHandler(
      player: JustAudioPort(),
      resolver: resolver,
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.metubesuper.audio',
      androidNotificationChannelName: 'MeTube Super',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  await handler.loadPreferences();

  // م-32: أثر إقلاع دائم — شاشة السجلات يجب ألا تكون فارغة أبداً بعد
  // أول تشغيل (كانت كذلك في Super لأن لا أحد يكتب فيها إطلاقاً).
  unawaited(logger.log('app started (super)', tag: 'app'));

  // **كنس الجزئيات اليتيمة (خ-3):** قتل التطبيق منتصف سحب كبير يترك
  // `.part` لا ينظفه أحد — مسح المكتبة يتجاهله عمداً، فالمساحة تضيع
  // بلا أن تُرى. لا ننتظره: الإقلاع لا يعلّق على تنظيف.
  unawaited(sweepPartialFiles(superMediaDir).then(
    (count) => count == 0 ? null : logger.log('swept $count partials'),
  ));

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
      child: const SuperApp(),
    ),
  );
}
