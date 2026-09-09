import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/app.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'playback_test_doubles.dart';

/// **Guards from field report 2026-09-05**: the Super server was put behind
/// Cloudflare Access, and the app became **a blank grey screen** with no
/// message in it.
///
/// The root was not the network: `AsyncError.value` in Riverpod **rethrows
/// the error**, and the pattern `AsyncValue(:final value?)` in the
/// library's first branch reads that getter, so the build exploded
/// **before** reaching the `AsyncError()` branch written a few lines below.
/// The error handling existed and was unreachable.
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
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => false,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
    );
  });

  tearDown(() => handler.dispose());

  /// An app configured with a server whose library fails with the given
  /// error.
  Widget appFailingWith(Object error) => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(mutex),
      initialSettingsProvider.overrideWithValue(
        const SuperSettings(
          activeUrl: 'https://mtube.example.com',
          localeCode: 'ar',
        ),
      ),
      playbackResolverProvider.overrideWithValue(handler.resolver),
      audioHandlerProvider.overrideWithValue(handler),
      loggerProvider.overrideWithValue(
        MTLogger(filePath: '${Directory.systemTemp.path}/mtf_auth.log'),
      ),
      libraryItemsProvider.overrideWith((ref) async => throw error),
    ],
    child: const SuperApp(),
  );

  Future<MTLocalizations> arabic() =>
      MTLocalizations.delegate.load(const Locale('ar'));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('رفض الاعتماد (401) ⇒ رسالة تقول سببه لا شاشة رمادية', (
    tester,
  ) async {
    await tester.pumpWidget(appFailingWith(const AuthFailureException('401')));
    await settle(tester);

    // **The first guard**: the build does not explode. On the old code
    // `AsyncError.value` threw here and the whole screen was replaced by
    // the grey `ErrorWidget` box (grey in release mode, with no text).
    expect(tester.takeException(), isNull);

    // **The second guard**: the cause is stated, and there is a path to
    // fixing it.
    final l10n = await arabic();
    expect(find.text(l10n.signInRequired), findsOneWidget);
    expect(find.text(l10n.updateCredentials), findsOneWidget);
  });

  testWidgets('عطل شبكة ⇒ رسالة الشبكة لا رسالة الاعتماد', (tester) async {
    await tester.pumpWidget(appFailingWith(const NetworkException('down')));
    await settle(tester);

    expect(tester.takeException(), isNull);
    final l10n = await arabic();
    // The distinction is deliberate: "update your password" is a wrong
    // diagnosis for a network outage, exactly as "could not reach" is a
    // wrong diagnosis for a rejected credential.
    expect(find.text(l10n.signInRequired), findsNothing);
    expect(find.text(l10n.connectionFailed), findsOneWidget);
    expect(find.text(l10n.errNetwork), findsOneWidget);
  });
}
