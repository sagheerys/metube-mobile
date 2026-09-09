import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/app.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'playback_test_doubles.dart';

void main() {
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;
  late MTAudioHandler handler;

  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
    handler = MTAudioHandler(
      player: FakeMediaPlayer(),
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint(
          buildUrl: (name) => 'https://srv/download/$name',
          headers: const {},
        ),
        fileExists: (path) => path == '/sd/a.mp3',
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
    );
  });

  tearDown(() => handler.dispose());

  Widget app() => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(mutex),
      initialSettingsProvider.overrideWithValue(const SuperSettings()),
      playbackResolverProvider.overrideWithValue(handler.resolver),
      audioHandlerProvider.overrideWithValue(handler),
      // The shell now drives the download notifications (2026-09-06) and
      // they log their failures, so the logger became part of the app's
      // startup.
      loggerProvider.overrideWithValue(
        MTLogger(filePath: '${Directory.systemTemp.path}/mtf_ui.log'),
      ),
    ],
    child: const SuperApp(),
  );

  testWidgets('الإقلاع بلا سيرفر ⇒ المكتبة بحالة «لا سيرفر بعد» (ر-1)', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(MTEmptyState), findsOneWidget);
    expect(find.byType(MTFab), findsOneWidget);
  });

  testWidgets('لا مشغل مصغر شبح عند الإقلاع بلا تشغيل (فخ §6.5)', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byType(MTMiniPlayer),
      findsOneWidget,
      reason: 'الودجت موجودة لكنها فارغة',
    );
    expect(
      find.byIcon(Icons.close_rounded),
      findsNothing,
      reason: 'لا شريط ظاهر ما دام mediaItem == null',
    );
  });

  testWidgets('تشغيل نسخة محلية بلا سيرفر يُظهر المشغل المصغر ثم stop يخفيه', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));

    // Real asynchronous work outside the fake clock, or the wait deadlocks.
    await tester.runAsync(
      () => handler.playItems(const [
        PlaylistItem(
          canonicalUrl: 'https://x/1',
          title: 'مقطع صوتي',
          localPath: '/sd/a.mp3',
          isAudio: true,
        ),
      ]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('مقطع صوتي'), findsOneWidget);

    await tester.runAsync(handler.stop);
    await tester.pump();
    // The mini player disappears with a fade and a shrink (polish
    // 2026-09-04), so we wait the full animation and then confirm it is
    // actually gone rather than fading.
    await tester.pump(MTMotion.reveal + const Duration(milliseconds: 50));
    expect(find.text('مقطع صوتي'), findsNothing);
  });
}
