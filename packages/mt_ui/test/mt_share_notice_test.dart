import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// The notice shown while Android's share plugin copies a file before its
/// menu opens: on screen before the copy, gone once the menu covers the app.
void main() {
  late BuildContext host;

  Widget app() => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    home: Builder(
      builder: (context) {
        host = context;
        return const Scaffold();
      },
    ),
  );

  testWidgets('the notice is on screen before the file is handed over', (
    tester,
  ) async {
    // Field report 2026-11-10: the app stood still for seconds with nothing
    // saying why, while a large file was copied.
    await tester.pumpWidget(app());
    var seenFirst = false;
    final send = Completer<void>();
    final done = mtShareWithNotice(host, () {
      seenFirst = find.text('Opening the share menu…').evaluate().isNotEmpty;
      return send.future;
    });
    await tester.pump();
    await tester.pump();
    expect(seenFirst, isTrue);

    send.complete();
    await tester.pumpAndSettle();
    await done;
    expect(find.text('Opening the share menu…'), findsNothing);
  });

  testWidgets('it goes as soon as the share menu covers the app', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    final send = Completer<void>();
    unawaited(mtShareWithNotice(host, () => send.future));
    await tester.pump();
    await tester.pump();
    expect(find.byType(MTShareOpening), findsOneWidget);

    // The menu is another window: the app is no longer the active one.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byType(MTShareOpening), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    send.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the notice fits both languages and both themes', (tester) async {
    for (final language in ['en', 'ar']) {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: MTLocalizations.localizationsDelegates,
            supportedLocales: MTLocalizations.supportedLocales,
            theme: mtTheme(MTVariant.lite, brightness),
            home: const Scaffold(body: MTShareOpening()),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
