import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/tags/item_tags_sheet.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Reported with a fix by Kasull-454 (2026-10-15).** With dozens of tags
/// the chips grew past the sheet and pushed the new-tag field and its
/// button off screen, with no way to reach them. The chips now scroll and
/// the field stays inside the sheet.
void main() {
  testWidgets('with many tags the new-tag field stays on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 823);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container.read(tagsIndexProvider).put('https://x/a', [
        for (var i = 0; i < 120; i++) 'tag number $i',
      ]),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    showItemTagsSheet(context, ref, const ['https://x/b']),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text('# tag number 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(823));
  });
}
