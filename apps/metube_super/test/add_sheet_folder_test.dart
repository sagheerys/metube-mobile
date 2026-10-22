import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/folders/folders_providers.dart';
import 'package:metube_super/features/home/add_flow.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **The folder in the add sheet**: picked among the server's own, sent
/// with the link, and absent for a playlist, which the batch screen saves
/// at the top.
void main() {
  late _Engine engine;

  Widget host(String url, {Locale locale = const Locale('en')}) {
    engine = _Engine();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => openAddSheet(context, ref, initialUrl: url),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(path: '/batch', builder: (_, _) => const Scaffold()),
      ],
    );
    return ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
        ),
        downloadEngineProvider.overrideWithValue(engine),
        serverFoldersProvider.overrideWith(
          (ref) async =>
              const ServerFolders(video: ['Ai', 'Ai/Lessons', 'Quran']),
        ),
        libraryFolderPathsProvider.overrideWithValue(const {}),
        foldersIgnoredProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        locale: locale,
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  Future<void> open(WidgetTester tester, String url) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(url));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a picked folder goes with the download', (tester) async {
    await open(tester, 'https://www.youtube.com/watch?v=jNQXAC9IVRw');
    expect(find.text('No folder'), findsOneWidget);

    await tester.tap(find.text('No folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(mtName('Lessons')));
    await tester.pumpAndSettle();
    expect(find.text(mtName('Ai/Lessons')), findsOneWidget);

    await tester.tap(find.text('Start download'));
    await tester.pumpAndSettle();
    expect(engine.folders, ['Ai/Lessons']);
  });

  testWidgets('left alone, it is the top, as before', (tester) async {
    await open(tester, 'https://www.youtube.com/watch?v=jNQXAC9IVRw');
    await tester.tap(find.text('Start download'));
    await tester.pumpAndSettle();
    expect(engine.folders, [null]);
  });

  testWidgets('a playlist has no folder row', (tester) async {
    await open(
      tester,
      'https://www.youtube.com/playlist?list=PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG',
    );
    expect(find.text('No folder'), findsNothing);
  });

  testWidgets('the sheet with its folder row holds on every device', (
    tester,
  ) async {
    await expectNoOverflow(tester, () => const _Opened());
  });
}

/// The sheet, opened once per size by the device matrix.
class _Opened extends StatelessWidget {
  const _Opened();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      initialSettingsProvider.overrideWithValue(const SuperSettings()),
      loggerProvider.overrideWithValue(
        MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
      ),
      downloadEngineProvider.overrideWithValue(null),
    ],
    child: MaterialApp.router(
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const _OpensSheet())],
      ),
    ),
  );
}

class _OpensSheet extends ConsumerStatefulWidget {
  const _OpensSheet();

  @override
  ConsumerState<_OpensSheet> createState() => _OpensSheetState();
}

class _OpensSheetState extends ConsumerState<_OpensSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => openAddSheet(
        context,
        ref,
        initialUrl: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

class _Engine implements DownloadEngine {
  final folders = <String?>[];

  @override
  DownloadTask submit(
    String url,
    Quality quality, {
    bool isBatchMember = false,
    String? folder,
  }) {
    folders.add(folder);
    return DownloadTask(inputUrl: url, quality: quality, folder: folder);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
