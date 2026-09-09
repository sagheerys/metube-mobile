import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/update/update_section.dart';
import 'package:metube_lite/features/update/update_sheet.dart';
import 'package:metube_lite/features/update/update_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'device_matrix.dart';

/// **Self-update from GitHub** — the app layer's guards.
///
/// The core is tested in `mt_core/test/update`; what is tested here belongs
/// to the app: the silent policy, skipping a version, and what the settings
/// row displays.
String releaseJson({String tag = 'v9.9.9'}) => json.encode({
  'tag_name': tag,
  'draft': false,
  'prerelease': false,
  'body': 'إصلاحات',
  'html_url': 'https://example.invalid/r',
  'assets': [
    {
      'name': 'MeTube-Lite-$tag.apk',
      'browser_download_url': 'https://example.invalid/app.apk',
      'size': 12582912,
    },
  ],
});

void main() {
  late MemoryKeyValueStore store;
  late Directory cacheDir;

  setUp(() {
    store = MemoryKeyValueStore();
    cacheDir = Directory.systemTemp.createTempSync('mt_update_test_');
    addTearDown(() {
      if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
    });
    PackageInfo.setMockInitialValues(
      appName: 'MeTube',
      packageName: 'com.yasir.test',
      version: '2.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  ProviderContainer container({
    String? body,
    Object? failWith,
    ApkDownloader? downloader,
  }) {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        // `path_provider` is a native channel and does not work in a widget
        // test.
        updateCacheDirProvider.overrideWith((ref) => cacheDir.path),
        if (downloader != null)
          apkDownloaderProvider.overrideWithValue(downloader),
        updateCheckerProvider.overrideWithValue(
          UpdateChecker(
            assetMarker: 'lite',
            fetch: (_) async {
              if (failWith != null) throw failWith;
              return body ?? releaseJson();
            },
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('the silent check', () {
    test('finds the newest release and sets the phase', () async {
      final c = container();
      await c.read(updateControllerProvider.notifier).checkSilently();
      final state = c.read(updateControllerProvider);
      expect(state.phase, UpdatePhase.available);
      expect(state.release!.version.toString(), '9.9.9');
      expect(state.release!.apkUrl, 'https://example.invalid/app.apk');
    });

    test('**the guard**: a network failure neither throws nor shows in the interface', () async {
      // The repository is private today, so GitHub answers 404 at every
      // launch. Any exception here reaches `initState` in the shell and
      // takes down the first frame.
      final c = container(failWith: Exception('404'));
      await c.read(updateControllerProvider.notifier).checkSilently();
      final state = c.read(updateControllerProvider);
      expect(state.phase, UpdatePhase.idle);
      expect(state.release, isNull);
      expect(state.failure, isNull);
    });

    test('**the guard**: it honours the interval rather than asking at every launch', () async {
      var calls = 0;
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          updateCheckerProvider.overrideWithValue(
            UpdateChecker(
              assetMarker: 'lite',
              fetch: (_) async {
                calls++;
                return releaseJson();
              },
            ),
          ),
        ],
      );
      addTearDown(c.dispose);

      await c.read(updateControllerProvider.notifier).checkSilently();
      expect(calls, 1);
      // A second launch minutes later: the stamp is kept in the same store.
      final second = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          updateCheckerProvider.overrideWithValue(
            UpdateChecker(
              assetMarker: 'lite',
              fetch: (_) async {
                calls++;
                return releaseJson();
              },
            ),
          ),
        ],
      );
      addTearDown(second.dispose);
      await second.read(updateControllerProvider.notifier).checkSilently();
      expect(calls, 1, reason: 'لا طلب ثانٍ قبل انقضاء المهلة');
    });

    test('switched off in settings means no request at all', () async {
      await store.setBool(UpdatePrefs.autoCheckKey, false);
      final c = container(failWith: StateError('يجب ألا يُطلب'));
      await c.read(updateControllerProvider.notifier).checkSilently();
      expect(c.read(updateControllerProvider).phase, UpdatePhase.idle);
    });
  });

  group('the manual check', () {
    test('it tells up to date apart from unreachable', () async {
      final upToDate = container(body: releaseJson(tag: 'v2.0.0'));
      await upToDate.read(updateControllerProvider.notifier).checkNow();
      expect(upToDate.read(updateControllerProvider).upToDate, isTrue);
      expect(upToDate.read(updateControllerProvider).failure, isNull);

      final broken = container(failWith: Exception('offline'));
      await broken.read(updateControllerProvider.notifier).checkNow();
      expect(
        broken.read(updateControllerProvider).failure,
        UpdateFailure.check,
      );
      expect(broken.read(updateControllerProvider).upToDate, isFalse);
    });

    test('**the guard**: it ignores a skipped version, because whoever pressed the button wants to know', () async {
      await store.setString(UpdatePrefs.skippedVersionKey, '9.9.9');
      final c = container();
      // The silent check mutes it…
      await c.read(updateControllerProvider.notifier).checkSilently();
      expect(c.read(updateControllerProvider).release, isNull);
      // …and the manual one shows it.
      await c.read(updateControllerProvider.notifier).checkNow();
      expect(c.read(updateControllerProvider).release, isNotNull);
    });
  });

  test('skipping is stored by version and hides the card', () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).checkSilently();
    await c.read(updateControllerProvider.notifier).skipCurrent();
    expect(await store.getString(UpdatePrefs.skippedVersionKey), '9.9.9');
    expect(c.read(updateControllerProvider).release, isNull);
    expect(c.read(updateControllerProvider).phase, UpdatePhase.idle);
  });

  group('sweeping the update file', () {
    File apkFile() => File('${cacheDir.path}/${MTConstants.updateApkFileName}');

    test('**the guard**: it is deleted once the app is the version that was downloaded', () async {
      // Without this, about 40MB stays in the cache forever after the first
      // successful update.
      apkFile().writeAsBytesSync(const [1, 2, 3]);
      await store.setString(UpdatePrefs.downloadedVersionKey, '2.0.0');

      final c = container();
      c.read(updateControllerProvider);
      // The sweep hangs off an asynchronous provider, so a single
      // `pumpEventQueue()` is a race rather than a wait: this test failed
      // once in a loaded full-suite run on 2026-09-09 and passed alone.
      // Waiting for the outcome keeps the guard and drops the flake.
      await _until(() => !apkFile().existsSync());

      expect(apkFile().existsSync(), isFalse);
      expect(await store.getString(UpdatePrefs.downloadedVersionKey), isNull);
    });

    test('an update downloaded but not yet installed stays where its owner left it', () async {
      apkFile().writeAsBytesSync(const [1, 2, 3]);
      await store.setString(UpdatePrefs.downloadedVersionKey, '9.9.9');

      final c = container();
      c.read(updateControllerProvider);
      // Nothing to wait for here — the point is that nothing happens — so
      // this pumps generously and then checks the file is still there.
      await pumpEventQueue(times: 100);

      expect(apkFile().existsSync(), isTrue);
      expect(await store.getString(UpdatePrefs.downloadedVersionKey), '9.9.9');
    });
  });

  group('the settings row', () {
    Widget host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: mtTheme(MTVariant.lite, Brightness.light),
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: UpdateSection()),
        ),
      ),
    );

    testWidgets(
      'with no update: an invitation to check, and the automatic switch on',
      (tester) async {
        final c = container();
        await tester.pumpWidget(host(c));
        await tester.pumpAndSettle();
        final l10n = tester.element(find.byType(UpdateSection)).mtl;

        expect(find.text(l10n.checkForUpdates), findsOneWidget);
        expect(find.text(l10n.updateAvailable), findsNothing);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );
      },
    );

    testWidgets(
      'with an update: a title in the accent colour, and the version number',
      (tester) async {
        final c = container();
        await c.read(updateControllerProvider.notifier).checkSilently();
        await tester.pumpWidget(host(c));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(UpdateSection));
        final l10n = context.mtl;

        expect(find.text(l10n.updateAvailable), findsOneWidget);
        expect(find.text('9.9.9'), findsOneWidget);
        // **The guard**: the colour comes from the palette rather than a
        // literal, or one app's colour leaks into the other.
        final title = tester.widget<Text>(find.text(l10n.updateAvailable));
        expect(title.style!.color, MTThemeX.of(context).palette.accent);
      },
    );

    testWidgets('**device matrix**: the row does not overflow', (tester) async {
      final c = container();
      await c.read(updateControllerProvider.notifier).checkSilently();
      await expectNoOverflow(tester, () => host(c));
    });
  });

  group('the update sheet', () {
    Widget sheetHost(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: mtTheme(MTVariant.lite, Brightness.light),
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        // As in the app: the sheet is not inside an outer scroll view.
        home: const Scaffold(body: UpdateSheet()),
      ),
    );

    testWidgets('shows the version, the size, what is new, and three actions', (
      tester,
    ) async {
      final c = container();
      await c.read(updateControllerProvider.notifier).checkSilently();
      await tester.pumpWidget(sheetHost(c));
      await tester.pumpAndSettle();
      final l10n = tester.element(find.byType(UpdateSheet)).mtl;

      expect(find.text(l10n.updateVersionAvailable('9.9.9')), findsOneWidget);
      // 12582912 bytes is exactly 12.0 MB: the size is displayed, not
      // guessed.
      expect(find.text(l10n.updateSizeMb('12.0')), findsOneWidget);
      expect(find.text('إصلاحات'), findsOneWidget);
      expect(find.text(l10n.updateNow), findsOneWidget);
      expect(find.text(l10n.updateLater), findsOneWidget);
      expect(find.text(l10n.updateSkipVersion), findsOneWidget);
    });

    testWidgets(
      '**the guard**: skipping from the sheet writes the preference',
      (tester) async {
        final c = container();
        await c.read(updateControllerProvider.notifier).checkSilently();
        await tester.pumpWidget(sheetHost(c));
        await tester.pumpAndSettle();
        final l10n = tester.element(find.byType(UpdateSheet)).mtl;

        await tester.tap(find.text(l10n.updateSkipVersion));
        await tester.pumpAndSettle();
        expect(await store.getString(UpdatePrefs.skippedVersionKey), '9.9.9');
      },
    );

    testWidgets(
      'the downloading phase: progress and cancel in place of the action buttons',
      (tester) async {
        final c = container(downloader: _StuckDownloader());
        await c.read(updateControllerProvider.notifier).checkSilently();
        await tester.pumpWidget(sheetHost(c));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(UpdateSheet));
        final l10n = context.mtl;

        unawaited(c.read(updateControllerProvider.notifier).download());
        await tester.pump();
        await tester.pump();

        final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(bar.value, 0.42);
        // **The guard**: the colour comes from the palette; Material's
        // default track comes out greenish over the Wahaj cream.
        expect(bar.valueColor!.value, MTThemeX.of(context).palette.accent);
        expect(find.text(l10n.cancel), findsOneWidget);
        expect(find.text(l10n.updateNow), findsNothing);
      },
    );

    testWidgets(
      '**device matrix**: no overflow across five sizes and three text scales',
      (tester) async {
        final c = container();
        await c.read(updateControllerProvider.notifier).checkSilently();
        await expectNoOverflow(tester, () => sheetHost(c));
      },
    );
  });
}

/// A download that never completes, pinning the phase at "downloading" so
/// the interface alone can be inspected.
class _StuckDownloader extends ApkDownloader {
  @override
  Future<String> download({
    required String url,
    required String savePath,
    int expectedSize = 0,
    void Function(double progress)? onProgress,
    DownloadCancelToken? cancel,
  }) {
    onProgress?.call(0.42);
    return Completer<String>().future;
  }
}

/// Pumps until [done] holds, or gives up and lets the assertion that
/// follows report the failure. Used where the outcome is asynchronous and
/// the machine may be busy.
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 50 && !done(); i++) {
    await pumpEventQueue(times: 10);
  }
}
