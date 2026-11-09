import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

import 'wahaj_finder.dart';

/// **The download card as the plan draws it** (mobile plan 2026-11-01): the
/// clip's picture, the server's speed beside the percentage, and a task
/// waiting its turn drawn still rather than as a moving bar.
void main() {
  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    home: Scaffold(body: child),
  );

  testWidgets('**the guard**: the speed shows beside the percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        MTDownloadProgressCard(
          title: 'Clip',
          statusText: 'On the server',
          progress: 0.64,
          detail: mtFormatTransferRate(3.1 * 1024 * 1024),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('3.1 MB/s'), findsOneWidget);
    expect(find.text('64%'), findsOneWidget);
  });

  testWidgets('**the guard**: a waiting task is a still line, not a moving '
      'bar', (tester) async {
    await tester.pumpWidget(
      host(
        const MTDownloadProgressCard(
          title: 'Clip',
          statusText: 'Number 2 in line',
          waiting: true,
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the picture takes the place of the icon', (tester) async {
    await tester.pumpWidget(
      host(
        const MTDownloadProgressCard(
          title: 'Clip',
          statusText: 'On the server',
          progress: 0.1,
          thumbnail: ColoredBox(key: Key('cover'), color: Colors.teal),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cover')), findsOneWidget);
    expect(byWahaj(MTIcons.download), findsNothing);
  });

  testWidgets('a failure opens to its whole reason on a tap, and closes', (
    tester,
  ) async {
    // Field report 2026-11-10: cut to one line, the reason never said what
    // was wrong.
    const reason =
        'ERROR: [youtube] dQw4w9WgXcQ: Sign in to confirm your age. This '
        'video may be inappropriate for some users.';
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      host(
        const MTDownloadProgressCard(
          title: 'Clip',
          statusText: reason,
          isError: true,
        ),
      ),
    );
    Text shown() => tester.widget<Text>(find.text(reason));
    final closed = tester.getSize(find.text(reason)).height;
    expect(shown().maxLines, 1);

    await tester.tap(find.text(reason));
    await tester.pumpAndSettle();
    expect(shown().maxLines, isNull);
    expect(tester.getSize(find.text(reason)).height, greaterThan(closed));

    await tester.tap(find.text(reason));
    await tester.pumpAndSettle();
    expect(shown().maxLines, 1);
  });

  testWidgets('a phase that is not a failure stays one line', (tester) async {
    await tester.pumpWidget(
      host(
        const MTDownloadProgressCard(
          title: 'Clip',
          statusText: 'On the server',
          progress: 0.2,
        ),
      ),
    );
    expect(find.byType(MTExpandableText), findsNothing);
  });

  test('the speed reads in kilobytes under a megabyte a second', () {
    expect(mtFormatTransferRate(512 * 1024), contains('512 KB/s'));
    expect(mtFormatTransferRate(1.5 * 1024 * 1024), contains('1.5 MB/s'));
  });
}
