import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/update/update_section.dart';
import 'package:metube_super/features/update/update_sheet.dart';
import 'package:metube_super/features/update/update_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// **التحديث الذاتي من GitHub (م-66)** — حرّاس طبقة التطبيق.
///
/// النواة مُختبَرة في `mt_core/test/update`؛ هنا يُختبر ما يخصّ التطبيق:
/// السياسة الصامتة، تخطّي إصدار، وما يعرضه صفّ الإعدادات.
String releaseJson({String tag = 'v9.9.9'}) => json.encode({
      'tag_name': tag,
      'draft': false,
      'prerelease': false,
      'body': 'إصلاحات',
      'html_url': 'https://example.invalid/r',
      'assets': [
        {
          'name': 'MeTube-Super-$tag.apk',
          'browser_download_url': 'https://example.invalid/app.apk',
          'size': 12582912,
        }
      ],
    });

void main() {
  late MemoryKeyValueStore store;

  setUp(() {
    store = MemoryKeyValueStore();
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
    final c = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      // `path_provider` قناة أصلية لا تعمل في اختبار ودجات.
      updateCacheDirProvider.overrideWith((ref) => Directory.systemTemp.path),
      if (downloader != null)
        apkDownloaderProvider.overrideWithValue(downloader),
      updateCheckerProvider.overrideWithValue(UpdateChecker(
        assetMarker: 'super',
        fetch: (_) async {
          if (failWith != null) throw failWith;
          return body ?? releaseJson();
        },
      )),
    ]);
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

    test('**الحارس**: عطل الشبكة لا يرمي ولا يترك أثراً في الواجهة',
        () async {
      // المستودع خاصٌّ اليوم ⇒ GitHub يردّ 404 عند كل إقلاع. أي استثناء
      // هنا يصل إلى `initState` في الغلاف فيسقط أول إطار.
      final c = container(failWith: Exception('404'));
      await c.read(updateControllerProvider.notifier).checkSilently();
      final state = c.read(updateControllerProvider);
      expect(state.phase, UpdatePhase.idle);
      expect(state.release, isNull);
      expect(state.failure, isNull);
    });

    test('**الحارس**: يحترم الإيقاع فلا يطلب عند كل إقلاع', () async {
      var calls = 0;
      final c = ProviderContainer(overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        updateCheckerProvider.overrideWithValue(UpdateChecker(
          assetMarker: 'super',
          fetch: (_) async {
            calls++;
            return releaseJson();
          },
        )),
      ]);
      addTearDown(c.dispose);

      await c.read(updateControllerProvider.notifier).checkSilently();
      expect(calls, 1);
      // إقلاع ثانٍ بعد دقائق: الختم محفوظ في التخزين نفسه.
      final second = ProviderContainer(overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        updateCheckerProvider.overrideWithValue(UpdateChecker(
          assetMarker: 'super',
          fetch: (_) async {
            calls++;
            return releaseJson();
          },
        )),
      ]);
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
      expect(broken.read(updateControllerProvider).failure, UpdateFailure.check);
      expect(broken.read(updateControllerProvider).upToDate, isFalse);
    });

    test('**الحارس**: لا يحترم التخطّي — من ضغط الزر يريد أن يعرف',
        () async {
      await store.setString(UpdatePrefs.skippedVersionKey, '9.9.9');
      final c = container();
      // الصامت يكتمه…
      await c.read(updateControllerProvider.notifier).checkSilently();
      expect(c.read(updateControllerProvider).release, isNull);
      // …واليدوي يُظهره.
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

  group('صفّ الإعدادات', () {
    Widget host(ProviderContainer c) => UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: mtTheme(MTVariant.superApp, Brightness.light),
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
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue);
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
      // **الحارس**: اللون من اللوحة لا قيمة مثبتة — وإلا تسرّب لون
      // أحد التطبيقين إلى الآخر.
      final title = tester.widget<Text>(find.text(l10n.updateAvailable));
      expect(title.style!.color, MTThemeX.of(context).palette.accent);
    });
  });

  group('ورقة التحديث', () {
    Widget sheetHost(ProviderContainer c) => UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: mtTheme(MTVariant.superApp, Brightness.light),
            locale: const Locale('ar'),
            localizationsDelegates: MTLocalizations.localizationsDelegates,
            supportedLocales: MTLocalizations.supportedLocales,
            home: const Scaffold(body: SingleChildScrollView(child: UpdateSheet())),
          ),
        );

    testWidgets('تعرض الإصدار والحجم وما الجديد وثلاثة أفعال', (tester) async {
      final c = container();
      await c.read(updateControllerProvider.notifier).checkSilently();
      await tester.pumpWidget(sheetHost(c));
      await tester.pumpAndSettle();
      final l10n = tester.element(find.byType(UpdateSheet)).mtl;

      expect(find.text(l10n.updateVersionAvailable('9.9.9')), findsOneWidget);
      // 12582912 بايت = 12.0 م.ب بالضبط — الحجم يُعرض لا يُخمَّن.
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
          find.byType(LinearProgressIndicator));
      expect(bar.value, 0.42);
      // **الحارس**: اللون من اللوحة — مسار Material الافتراضي يخرج
      // مخضرّاً على كريمي «وهج».
      expect(bar.valueColor!.value, MTThemeX.of(context).palette.accent);
      expect(find.text(l10n.cancel), findsOneWidget);
      expect(find.text(l10n.updateNow), findsNothing);
    });
  });
}

/// منزّل لا يكتمل — يثبّت الطور عند «قيد التنزيل» لفحص الواجهة وحدها.
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
