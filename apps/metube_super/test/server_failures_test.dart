import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/server_failures.dart';
import 'package:metube_super/features/library/widgets/downloads_sheet.dart';
import 'package:metube_super/features/library/widgets/server_failures_section.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Downloads that did not finish on the server**, whoever added them:
/// listed, retried and removed — and a finished download, which is a
/// library item, is never touched by either.
void main() {
  late _Server server;
  late _Engine engine;

  setUp(() {
    server = _Server([
      _row(
        'https://youtu.be/aaa',
        'error',
        title: 'Lesson one',
        msg: 'ERROR: [youtube] aaa: Video unavailable',
        quality: '480',
        folder: 'Ai',
      ),
      _row(
        'https://youtu.be/bbb',
        'error',
        title: 'A song',
        msg: 'ERROR: HTTP Error 429',
        type: 'audio',
      ),
      _row('https://youtu.be/done', 'finished', title: 'In the library'),
    ]);
    engine = _Engine(server.calls);
  });

  List<Override> overrides({List<DownloadTask> tasks = const []}) => [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    secretStoreProvider.overrideWithValue(MemorySecretStore()),
    prefsMutexProvider.overrideWithValue(PrefsMutex()),
    initialSettingsProvider.overrideWithValue(
      const SuperSettings(activeUrl: 'https://srv.example.com'),
    ),
    loggerProvider.overrideWithValue(
      MTLogger(filePath: '${Directory.systemTemp.path}/mtf_failures.log'),
    ),
    apiClientProvider.overrideWithValue(server.api),
    downloadEngineProvider.overrideWithValue(engine),
    engineTasksProvider.overrideWith((ref) => Stream.value(tasks)),
  ];

  Future<ProviderContainer> ready({List<DownloadTask> tasks = const []}) async {
    final container = ProviderContainer(overrides: overrides(tasks: tasks));
    addTearDown(container.dispose);
    container.listen(engineTasksProvider, (_, _) {});
    await container.read(engineTasksProvider.future);
    await container.read(historyProvider.future);
    return container;
  }

  group('the list', () {
    test('holds the failed rows and not the finished one', () async {
      final container = await ready();
      final urls = [
        for (final item in container.read(serverFailuresProvider))
          item.canonicalUrl,
      ];
      expect(urls, ['https://youtu.be/aaa', 'https://youtu.be/bbb']);
    });

    test('leaves out a failure this phone already shows as its own', () async {
      final container = await ready(
        tasks: [
          DownloadTask(
            inputUrl: 'https://youtu.be/aaa',
            canonicalUrl: 'https://youtu.be/aaa',
            quality: Quality.best,
            phase: TaskPhase.failed,
          ),
        ],
      );
      expect(
        container.read(serverFailuresProvider).map((i) => i.canonicalUrl),
        ['https://youtu.be/bbb'],
      );
    });
  });

  group('removing', () {
    test(
      'sends only rows still failed when asked, never a finished one',
      () async {
        final container = await ready();
        // Retried from MeTube's page since the sheet was read: it finished.
        server.finish('https://youtu.be/aaa');

        final removed = await container
            .read(serverFailureActionsProvider)
            .remove([
              'https://youtu.be/aaa',
              'https://youtu.be/bbb',
              'https://youtu.be/done',
            ]);

        expect(removed, 1);
        expect(server.deleted, ['https://youtu.be/bbb']);
        expect(server.has('https://youtu.be/aaa'), isTrue);
        expect(server.has('https://youtu.be/done'), isTrue);
      },
    );
  });

  group('retrying', () {
    test(
      'removes the failed row first, then adds it as it was added',
      () async {
        final container = await ready();
        final items = container.read(serverFailuresProvider);

        final sent = await container
            .read(serverFailureActionsProvider)
            .retry(items);

        expect(sent, 2);
        expect(server.calls, [
          'history',
          'history',
          'delete https://youtu.be/aaa,https://youtu.be/bbb',
          'submit https://youtu.be/aaa 480 Ai',
          'submit https://youtu.be/bbb audio -',
        ]);
      },
    );
  });

  group('the reason', () {
    String? reason(String msg) =>
        failureReason(HistoryItem(id: 'x', canonicalUrl: 'x', error: msg));

    test('is the first sentence, as measured on a real server', () {
      expect(
        reason(
          '[youtube] This video is unavailable\nNo video formats found!\n'
          'Requested format is not available',
        ),
        'This video is unavailable',
      );
      expect(
        reason('ERROR: [youtube] aaa: Video unavailable'),
        'Video unavailable',
      );
      expect(reason('URL is missing a host'), 'URL is missing a host');
      expect(reason('ERROR: HTTP Error 429'), 'HTTP Error 429');
    });
  });

  group('on screen', () {
    Widget app(Widget home) => ProviderScope(
      overrides: overrides(),
      child: MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: home,
      ),
    );

    Widget library() => app(
      Scaffold(
        body: Builder(
          builder: (context) => ListView(
            children: [
              ServerFailuresLine(
                onOpen: () => showDownloadsSheet(context, toFailures: true),
              ),
            ],
          ),
        ),
      ),
    );

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(library());
      await tester.pumpAndSettle();
    }

    testWidgets('one line in the library opens the failures', (tester) async {
      await open(tester);
      expect(
        find.text("2 downloads didn't finish on the server"),
        findsOneWidget,
      );

      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(find.text("Didn't finish on the server"), findsOneWidget);
      // The server's reason, without yt-dlp's own prefix and the id.
      expect(find.text(mtName('Video unavailable')), findsOneWidget);
    });

    testWidgets('"remove the failed" says the library stays, and removes '
        'only the failed rows', (tester) async {
      await open(tester);
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove the failed'));
      await tester.pumpAndSettle();
      expect(find.text('Remove 2 failed downloads?'), findsOneWidget);
      expect(find.textContaining('Everything that finished'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Remove the failed'));
      await tester.pumpAndSettle();
      expect(server.deleted, ['https://youtu.be/aaa', 'https://youtu.be/bbb']);
      expect(server.has('https://youtu.be/done'), isTrue);
    });

    testWidgets('nothing at all when nothing failed', (tester) async {
      server = _Server([
        _row('https://youtu.be/done', 'finished', title: 'In the library'),
      ]);
      await open(tester);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('the line and the section fit every device and font scale', (
      tester,
    ) async {
      await expectNoOverflow(
        tester,
        () => app(
          Consumer(
            builder: (context, ref, _) => Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(MTSpace.pagePad),
                children: [
                  ServerFailuresLine(onOpen: () {}),
                  ServerFailuresSection(
                    items: ref.watch(serverFailuresProvider),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  });
}

Map<String, Object?> _row(
  String url,
  String status, {
  String? title,
  String? msg,
  String quality = 'best',
  String type = 'video',
  String? folder,
}) => {
  'id': url,
  'url': url,
  'title': title,
  'status': status,
  'msg': ?msg,
  'quality': quality,
  'format': 'any',
  'download_type': type,
  'folder': ?folder,
};

/// A MeTube that keeps its rows and the order of what it was asked.
class _Server {
  _Server(List<Map<String, Object?>> rows) : _rows = [...rows] {
    api = MeTubeApiClient(
      config: ServerConfig(baseUrl: 'https://srv.example.com'),
      dio: Dio()..httpClientAdapter = _Adapter(_handle),
    );
  }

  final List<Map<String, Object?>> _rows;
  final List<String> calls = [];
  final List<String> deleted = [];
  late final MeTubeApiClient api;

  bool has(String url) => _rows.any((r) => r['url'] == url);

  void finish(String url) {
    final row = _rows.firstWhere((r) => r['url'] == url);
    row['status'] = 'finished';
    row.remove('msg');
  }

  ResponseBody _handle(RequestOptions options) {
    if (options.path.endsWith('/history')) {
      calls.add('history');
      return _json({'done': _rows, 'queue': const [], 'pending': const []});
    }
    if (options.path.endsWith('/delete')) {
      final body = jsonDecode(options.data as String) as Map<String, dynamic>;
      final ids = [for (final id in body['ids'] as List) id as String];
      calls.add('delete ${ids.join(',')}');
      deleted.addAll(ids);
      _rows.removeWhere((r) => ids.contains(r['url']));
      return _json({'status': 'ok'});
    }
    return _json({'status': 'ok'});
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class _Engine implements DownloadEngine {
  _Engine(this.calls);

  final List<String> calls;

  @override
  DownloadTask submit(
    String url,
    Quality quality, {
    bool isBatchMember = false,
    String? folder,
  }) {
    calls.add('submit $url ${quality.wire} ${folder ?? '-'}');
    return DownloadTask(inputUrl: url, quality: quality, folder: folder);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
