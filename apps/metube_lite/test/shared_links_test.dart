import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:metube_lite/features/shell/shared_links.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// Several links shared at once are asked about before anything reaches
/// the server (security review 2026-11-05).
void main() {
  const links = [
    'https://www.youtube.com/watch?v=jNQXAC9IVRw',
    'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
    'https://vimeo.com/76979871',
  ];

  Widget host(_Engine engine, {bool capped = false, String language = 'en'}) =>
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(const LiteSettings()),
          loggerProvider.overrideWithValue(
            MTLogger(filePath: '${Directory.systemTemp.path}/mtf_links.log'),
          ),
          downloadEngineProvider.overrideWithValue(engine),
        ],
        child: MaterialApp.router(
          locale: Locale(language),
          theme: mtTheme(MTVariant.lite, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => Scaffold(
                  body: Consumer(
                    builder: (context, ref, _) => TextButton(
                      onPressed: () => submitSharedLinks(
                        context,
                        ref,
                        links,
                        capped: capped,
                        note: (_) {},
                      ),
                      child: const Text('SHARE'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  testWidgets('**the guard**: nothing is sent until the user agrees, and '
      'nothing at all on cancel', (tester) async {
    final engine = _Engine();
    await tester.pumpWidget(host(engine));
    await tester.tap(find.text('SHARE'));
    await tester.pumpAndSettle();
    expect(find.text('Add 3 links?'), findsOneWidget);
    expect(engine.urls, isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(engine.urls, isEmpty);
  });

  testWidgets('agreeing sends every link', (tester) async {
    final engine = _Engine();
    await tester.pumpWidget(host(engine));
    await tester.tap(find.text('SHARE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add them'));
    await tester.pumpAndSettle();
    expect(engine.urls, links);
  });

  testWidgets('a share past the ceiling says the rest was left', (
    tester,
  ) async {
    final engine = _Engine();
    await tester.pumpWidget(host(engine, capped: true));
    await tester.tap(find.text('SHARE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add them'));
    await tester.pump();
    expect(
      find.text('Only the first $maxSharedLinks links were added.'),
      findsOneWidget,
    );
  });

  testWidgets('the question reads in Arabic, at the largest text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: host(_Engine(), language: 'ar'),
      ),
    );
    await tester.tap(find.text('SHARE'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة 3 روابط؟'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Engine implements DownloadEngine {
  final urls = <String>[];

  @override
  DownloadTask submit(
    String url,
    Quality quality, {
    bool isBatchMember = false,
    String? folder,
  }) {
    urls.add(url);
    return DownloadTask(inputUrl: url, quality: quality, folder: folder);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
