import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/widgets/downloads_sheet.dart';
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
    List<DownloadTask> first,
  ) async {
    tester.view.physicalSize = const Size(384, 823);
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
          theme: mtTheme(MTVariant.superApp, Brightness.light),
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
}
