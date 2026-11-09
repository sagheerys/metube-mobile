import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/features/downloads/panel_line.dart';
import 'package:mt_ui/mt_ui.dart';

/// A line of the downloads panel: a failure's reason opens to its whole
/// text on a click, as on the phones.
void main() {
  const reason =
      'ERROR: [youtube] dQw4w9WgXcQ: Sign in to confirm your age. This video '
      'may be inappropriate for some users, and the rest of the server text '
      'goes on long enough to need more than two lines.';

  Widget host(Widget line) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      home: Scaffold(body: SizedBox(width: 360, child: line)),
    ),
  );

  testWidgets('a failure opens to its whole reason on a click', (tester) async {
    // Field report 2026-11-10: two lines cut the reason before the part
    // that said what went wrong.
    await tester.pumpWidget(
      host(const PanelLine(title: 'Clip', status: reason, error: true)),
    );
    Text shown() => tester.widget<Text>(find.text(reason));
    expect(shown().maxLines, 2);
    await tester.tap(find.text(reason));
    await tester.pumpAndSettle();
    expect(shown().maxLines, isNull);
  });

  testWidgets('a line that did not fail keeps its two lines', (tester) async {
    await tester.pumpWidget(
      host(const PanelLine(title: 'Clip', status: 'On the server')),
    );
    expect(find.byType(MTExpandableText), findsNothing);
  });
}
