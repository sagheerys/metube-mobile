import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:metube_lite/features/downloads_library/widgets/item_details_sheet.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// A clip's title in its details can be selected and copied, to look it up
/// elsewhere (owner's request 2026-11-11).
void main() {
  testWidgets('**the guard**: the title can be selected and copied', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final item = LocalItem(
      key: 'https://youtu.be/jNQXAC9IVRw',
      path: '${Directory.systemTemp.path}/Me at the zoo.mp4',
      title: 'Me at the zoo',
      sizeBytes: 1000,
      modified: DateTime(2026, 11, 1),
      canonicalUrl: 'https://youtu.be/jNQXAC9IVRw',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(const LiteSettings()),
          loggerProvider.overrideWithValue(
            MTLogger(filePath: '${Directory.systemTemp.path}/mtf_details.log'),
          ),
        ],
        child: MaterialApp(
          theme: mtTheme(MTVariant.lite, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showItemDetailsSheet(context, item),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('Me at the zoo'),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
  });
}
