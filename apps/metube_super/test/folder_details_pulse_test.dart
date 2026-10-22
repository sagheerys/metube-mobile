import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/folders/folder_widgets.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/widgets/item_details_sheet.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

Widget _app(Widget home) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    secretStoreProvider.overrideWithValue(MemorySecretStore()),
    prefsMutexProvider.overrideWithValue(PrefsMutex()),
    initialSettingsProvider.overrideWithValue(const SuperSettings()),
    loggerProvider.overrideWithValue(
      MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
    ),
  ],
  child: MaterialApp(
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  group("the clip's folder in its details", () {
    Future<void> open(WidgetTester tester, String path) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final item = LibraryItem(
        canonicalUrl: 'https://youtu.be/jNQXAC9IVRw',
        title: 'Me at the zoo',
        serverFilename: path,
        onServer: true,
      );
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showItemDetailsSheet(context, item),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('is shown with its full path', (tester) async {
      await open(tester, 'Ai/Lessons/Me at the zoo [jNQXAC9IVRw].webm');
      expect(find.text('Folder'), findsOneWidget);
      expect(find.text(mtName('Ai/Lessons')), findsOneWidget);
    });

    testWidgets('is left out for a clip at the top', (tester) async {
      await open(tester, 'Me at the zoo [jNQXAC9IVRw].webm');
      expect(find.text('Folder'), findsNothing);
    });
  });

  group('the pulsing help', () {
    Widget pulse({bool still = false}) => _app(
      MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: const Scaffold(
          body: Center(child: PulsingHelp(child: Icon(Icons.help))),
        ),
      ),
    );

    double scale(WidgetTester tester) => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(PulsingHelp),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .getMaxScaleOnAxis();

    testWidgets('pulses three times as it appears, then stays still', (
      tester,
    ) async {
      await tester.pumpWidget(pulse());
      await tester.pump(MTMotion.slow ~/ 2);
      expect(scale(tester), greaterThan(1.1));
      await tester.pump(MTMotion.slow * 3);
      await tester.pumpAndSettle();
      expect(scale(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('does not move when the system asks for less motion', (
      tester,
    ) async {
      await tester.pumpWidget(pulse(still: true));
      await tester.pump(MTMotion.slow ~/ 2);
      expect(scale(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
