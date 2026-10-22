import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/folders/folders_providers.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/library/widgets/sort_sheet.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

HistoryItem _done(String folder, String filename, int seconds) =>
    HistoryItem.fromJson({
      'url': 'https://youtu.be/$seconds',
      'folder': folder,
      'filename': filename,
      'status': 'finished',
      'timestamp': seconds * 1000000000,
    });

void main() {
  group('the "server ignores folders" notice', () {
    Future<bool> ignored(List<HistoryItem> done) async {
      final c = ProviderContainer(
        overrides: [
          historyProvider.overrideWith(
            (ref) async => HistoryResponse(done: done),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(historyProvider.future);
      return c.read(foldersIgnoredProvider);
    }

    // Measured on the owner's server 2026-10-22: two downloads from before
    // the fix stay in the history as `../name`, and the newer ones are in
    // their folders.
    test('goes once the newest folder download is in its folder', () async {
      expect(
        await ignored([
          _done('Ai', '../old.mp4', 100),
          _done('Ai', '../older.mp4', 50),
          _done('Games', 'new.mp4', 200),
        ]),
        isFalse,
      );
    });

    test('shows while the newest one still lands at the top', () async {
      expect(
        await ignored([
          _done('Ai', 'early.mp4', 100),
          _done('Ai', '../late.mp4', 200),
        ]),
        isTrue,
      );
    });

    test('says nothing on a server never asked for a folder', () async {
      expect(await ignored([_done('', 'a.mp4', 100)]), isFalse);
    });
  });

  group('the sort sheet with many folders', () {
    LibraryItem at(String path) => LibraryItem(
      canonicalUrl: 'https://youtu.be/$path',
      title: path,
      serverFilename: path,
      onServer: true,
    );
    final many = [
      for (var i = 0; i < 24; i++)
        for (var j = 0; j <= i % 3; j++) at('Folder $i/clip $j.mp4'),
    ];

    Widget host(
      List<LibraryItem> items, {
      Locale locale = const Locale('en'),
    }) => ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        platformCountsProvider.overrideWithValue([
          for (final p in MediaPlatform.values) MapEntry(p, 12),
        ]),
        libraryItemsProvider.overrideWith((ref) async => items),
      ],
      child: MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        locale: locale,
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: const _OpensSortSheet(),
      ),
    );

    testWidgets('folds after eight, and "more" shows the rest', (tester) async {
      tester.view.physicalSize = const Size(384, 823);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(many));
      await tester.pumpAndSettle();
      expect(find.text('More · 16'), findsOneWidget);
      await tester.ensureVisible(find.text('More · 16'));
      await tester.tap(find.text('More · 16'));
      await tester.pumpAndSettle();
      expect(find.textContaining('More ·'), findsNothing);
      expect(find.textContaining('Folder 0'), findsOneWidget);
    });

    testWidgets('holds on every device and text scale, in both languages', (
      tester,
    ) async {
      await expectNoOverflow(tester, () => host(many));
      await expectNoOverflow(
        tester,
        () => host(many, locale: const Locale('ar')),
      );
    });
  });
}

class _OpensSortSheet extends ConsumerStatefulWidget {
  const _OpensSortSheet();

  @override
  ConsumerState<_OpensSortSheet> createState() => _OpensSortSheetState();
}

class _OpensSortSheetState extends ConsumerState<_OpensSortSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showSortSheet(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
