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

  group('الفحص الصامت', () {
    test('يجد الأحدث ويضبط الطور', () async {
      final c = container();
      await c.read(updateControllerProvider.notifier).checkSilently();
      final state = c.read(updateControllerProvider);
      expect(state.phase, UpdatePhase.available);
      expect(state.release!.version.toString(), '9.9.9');
      expect(state.release!.apkUrl, 'https://example.invalid/app.apk');
    });

    test('**الحارس**: عطل الشبكة لا يرمي ولا يترك أثراً في الواجهة', () async {
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

    test('**الحارس**: يحترم الإيقاع فلا يطلب عند كل إقلاع', () async {
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

    test('مطفأ من الإعدادات ⇒ لا طلب إطلاقاً', () async {
      await store.setBool(UpdatePrefs.autoCheckKey, false);
      final c = container(failWith: StateError('يجب ألا يُطلب'));
      await c.read(updateControllerProvider.notifier).checkSilently();
      expect(c.read(updateControllerProvider).phase, UpdatePhase.idle);
    });
  });

  group('الفحص اليدوي', () {
    test('يميّز «لا جديد» عن «تعذّر الوصول»', () async {
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

    test('**الحارس**: لا يحترم التخطّي — من ضغط الزر يريد أن يعرف', () async {
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

  test('التخطّي يُكتب بالإصدار ويُخفي البطاقة', () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).checkSilently();
    await c.read(updateControllerProvider.notifier).skipCurrent();
    expect(await store.getString(UpdatePrefs.skippedVersionKey), '9.9.9');
    expect(c.read(updateControllerProvider).release, isNull);
    expect(c.read(updateControllerProvider).phase, UpdatePhase.idle);
  });

  group('كنس ملف التحديث', () {
    File apkFile() => File('${cacheDir.path}/${MTConstants.updateApkFileName}');

    test('**الحارس**: يُمسح بعد أن يصير التطبيق هو الإصدار المنزَّل', () async {
      // Without this, about 40MB stays in the cache forever after the first
      // successful update.
      apkFile().writeAsBytesSync(const [1, 2, 3]);
      await store.setString(UpdatePrefs.downloadedVersionKey, '2.0.0');

      final c = container();
      c.read(updateControllerProvider);
      await pumpEventQueue();

      expect(apkFile().existsSync(), isFalse);
      expect(await store.getString(UpdatePrefs.downloadedVersionKey), isNull);
    });

    test('تحديث نُزّل ولم يُثبَّت بعد يبقى كما تركه صاحبه', () async {
      apkFile().writeAsBytesSync(const [1, 2, 3]);
      await store.setString(UpdatePrefs.downloadedVersionKey, '9.9.9');

      final c = container();
      c.read(updateControllerProvider);
      await pumpEventQueue();

      expect(apkFile().existsSync(), isTrue);
      expect(await store.getString(UpdatePrefs.downloadedVersionKey), '9.9.9');
    });
  });

  group('صفّ الإعدادات', () {
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

    testWidgets('بلا تحديث: دعوة للفحص ومفتاح تلقائي مفعّل', (tester) async {
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
    });

    testWidgets('مع تحديث: عنوان بلون الفعل ورقم الإصدار', (tester) async {
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
    });

    testWidgets('**مصفوفة الأجهزة**: الصفّ بلا تجاوز إطار', (tester) async {
      final c = container();
      await c.read(updateControllerProvider.notifier).checkSilently();
      await expectNoOverflow(tester, () => host(c));
    });
  });

  group('ورقة التحديث', () {
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

    testWidgets('تعرض الإصدار والحجم وما الجديد وثلاثة أفعال', (tester) async {
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

    testWidgets('**الحارس**: التخطّي من الورقة يكتب المفتاح', (tester) async {
      final c = container();
      await c.read(updateControllerProvider.notifier).checkSilently();
      await tester.pumpWidget(sheetHost(c));
      await tester.pumpAndSettle();
      final l10n = tester.element(find.byType(UpdateSheet)).mtl;

      await tester.tap(find.text(l10n.updateSkipVersion));
      await tester.pumpAndSettle();
      expect(await store.getString(UpdatePrefs.skippedVersionKey), '9.9.9');
    });

    testWidgets('طور التنزيل: تقدّم وإلغاء بدل أزرار الفعل', (tester) async {
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
    });

    testWidgets(
      '**مصفوفة الأجهزة**: لا تجاوز إطار على خمسة مقاسات × ثلاثة مقاييس خط',
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
