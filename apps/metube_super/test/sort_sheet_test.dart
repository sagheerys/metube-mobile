import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/library/widgets/sort_sheet.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// Field report 2026-10-15: with the platforms section in it, the view
/// sheet stopped at nine sixteenths of the screen and the view modes had to
/// be scrolled to.
void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'the view modes show without scrolling (${locale.languageCode})',
      (tester) async {
        tester.view.physicalSize = const Size(384, 823);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
              prefsMutexProvider.overrideWithValue(PrefsMutex()),
              platformCountsProvider.overrideWithValue([
                for (final p in const [
                  MediaPlatform.youtube,
                  MediaPlatform.instagram,
                  MediaPlatform.tiktok,
                  MediaPlatform.x,
                  MediaPlatform.facebook,
                  MediaPlatform.soundcloud,
                ])
                  MapEntry(p, 12),
              ]),
            ],
            child: MaterialApp(
              theme: mtTheme(MTVariant.superApp, Brightness.light),
              locale: locale,
              localizationsDelegates: MTLocalizations.localizationsDelegates,
              supportedLocales: MTLocalizations.supportedLocales,
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () => showSortSheet(context, ref),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // The view modes, the choice used most, sit inside the sheet as it
        // opens. The test font is wider than any real one, so the
        // platforms below may still need a scroll here.
        final sheet = tester.getRect(find.byType(BottomSheet));
        final cards = tester.getRect(
          find.byWidgetPredicate(
            (w) =>
                w is ChoiceChip &&
                (w.label as Text).data ==
                    lookupMTLocalizations(locale).viewCards,
          ),
        );
        expect(cards.bottom, lessThanOrEqualTo(sheet.bottom));
      },
    );
  }

  testWidgets('the folders appear only on a server that has them, and a '
      'choice filters the library', (tester) async {
    late WidgetRef captured;
    Future<void> pump(List<MapEntry<String, int>> folders) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
            prefsMutexProvider.overrideWithValue(PrefsMutex()),
            platformCountsProvider.overrideWithValue(const []),
            folderCountsProvider.overrideWithValue(folders),
          ],
          child: MaterialApp(
            theme: mtTheme(MTVariant.superApp, Brightness.light),
            localizationsDelegates: MTLocalizations.localizationsDelegates,
            supportedLocales: MTLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  captured = ref;
                  return TextButton(
                    onPressed: () => showSortSheet(context, ref),
                    child: const Text('open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    await pump(const []);
    expect(find.text('All folders'), findsNothing);

    await pump(const [MapEntry('Kids', 3)]);
    expect(find.text('All folders'), findsOneWidget);
    await tester.tap(find.textContaining('Kids'));
    await tester.pumpAndSettle();
    expect(captured.read(libraryViewProvider).folder, 'Kids');
  });
}
