import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_models.dart';
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

  testWidgets('the folders appear only on a server that has them, one row '
      'per level, and the chosen one goes back up when tapped again', (
    tester,
  ) async {
    late WidgetRef captured;
    LibraryItem at(String path) => LibraryItem(
      canonicalUrl: 'https://youtu.be/$path',
      title: path,
      serverFilename: path,
      onServer: true,
    );
    Future<void> pump(List<LibraryItem> items) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
            prefsMutexProvider.overrideWithValue(PrefsMutex()),
            platformCountsProvider.overrideWithValue(const []),
            libraryItemsProvider.overrideWith((ref) async => items),
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
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    String? chosen() => captured.read(libraryViewProvider).folder;

    await pump([at('a.mp4')]);
    expect(find.text('All folders'), findsNothing);

    await pump([
      at('Ai/a.mp4'),
      at('Ai/Lessons/b.mp4'),
      at('Ai/Lessons/c.mp4'),
      at('Quran/d.mp4'),
    ]);
    expect(find.text('All folders'), findsOneWidget);
    expect(find.textContaining('Lessons'), findsNothing);

    await tester.tap(find.textContaining('Ai'));
    await tester.pumpAndSettle();
    expect(chosen(), 'Ai');
    await tester.tap(find.textContaining('Lessons'));
    await tester.pumpAndSettle();
    expect(chosen(), 'Ai/Lessons');
    await tester.tap(find.textContaining('Lessons'));
    await tester.pumpAndSettle();
    expect(chosen(), 'Ai');
  });
}
