import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/widgets/downloads_sheet.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// Field report 2026-10-15: when the last download finished, the open
/// sheet leapt to the top of the screen to say there were none.
void main() {
  final running = DownloadTask(
    inputUrl: 'https://youtu.be/abc',
    quality: Quality.best,
  ).copyWith(phase: TaskPhase.polling);

  Future<StreamController<List<DownloadTask>>> open(
    WidgetTester tester,
    List<DownloadTask> first, {
    Size size = const Size(384, 823),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tasks = StreamController<List<DownloadTask>>();
    addTearDown(tasks.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadEngineProvider.overrideWithValue(null),
          engineTasksProvider.overrideWith((ref) => tasks.stream),
        ],
        child: MaterialApp(
          theme: mtTheme(MTVariant.lite, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDownloadsSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    tasks.add(first);
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return tasks;
  }

  double height(WidgetTester tester) =>
      tester.getSize(find.byType(BottomSheet)).height;

  testWidgets('the last download finishing leaves the sheet where it was', (
    tester,
  ) async {
    final tasks = await open(tester, [running]);
    final before = height(tester);

    tasks.add([running.copyWith(phase: TaskPhase.completed)]);
    await tester.pumpAndSettle();
    expect(find.text('No Downloads'), findsOneWidget);
    expect(height(tester), before);
  });

  testWidgets('opened with nothing running, the sheet is only as tall as '
      'its message', (tester) async {
    await open(tester, const []);
    expect(find.text('No Downloads'), findsOneWidget);
    expect(height(tester), lessThan(823 / 2));
  });

  testWidgets('emptied on a tablet held sideways, the message still fits', (
    tester,
  ) async {
    final tasks = await open(tester, [running], size: const Size(948, 544));
    // Dragged as low as it goes before the last download finishes.
    await tester.drag(
      find.byType(MTDownloadProgressCard),
      const Offset(0, 140),
    );
    await tester.pumpAndSettle();

    tasks.add([running.copyWith(phase: TaskPhase.completed)]);
    await tester.pumpAndSettle();
    expect(find.text('No Downloads'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pull counts up from zero, not down from the server'
      "'s hundred", (tester) async {
    final tasks = await open(tester, [running.copyWith(progress: 1)]);
    expect(find.text('100%'), findsOneWidget);

    tasks.add([running.copyWith(phase: TaskPhase.pulling, progress: 0)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('0%'), findsOneWidget);
  });
}
