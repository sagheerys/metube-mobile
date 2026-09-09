import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/artwork_view.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/library/widgets/library_chips.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The fourth view mode and the platform filter** (requested 2026-09-08).
///
/// Three independent guards: migrating the view mode from the two old keys,
/// computing the decode width, and the active platform appearing in the
/// first row.
void main() {
  late MemoryKeyValueStore store;

  setUp(() => store = MemoryKeyValueStore());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<LibraryViewOptions> restored(ProviderContainer c) async {
    c.read(libraryViewProvider);
    await pumpEventQueue();
    return c.read(libraryViewProvider);
  }

  group('the view mode: four modes under one key', () {
    test('nothing saved means the list', () async {
      expect((await restored(container())).mode, LibraryViewMode.list);
    });

    /// **The guard**: someone updating the app while on grid must find it
    /// as they left it.
    test('migrating from the old library_grid_view key', () async {
      await store.setBool('library_grid_view', true);
      final options = await restored(container());
      expect(options.mode, LibraryViewMode.grid);
      expect(options.grid, isTrue);
      expect(options.compact, isFalse);
    });

    test('migrating from the old library_compact_view key', () async {
      await store.setBool('library_compact_view', true);
      expect((await restored(container())).mode, LibraryViewMode.compact);
    });

    test('the new key beats both old ones', () async {
      await store.setBool('library_grid_view', true);
      await store.setString('library_view_mode', 'cards');
      final options = await restored(container());
      expect(options.mode, LibraryViewMode.cards);
      expect(options.cards, isTrue);
      expect(options.grid, isFalse);
    });

    test('switching is saved by name, not by a flag', () async {
      final c = container();
      await restored(c);
      await c.read(libraryViewProvider.notifier).setMode(LibraryViewMode.cards);
      expect(await store.getString('library_view_mode'), 'cards');
      expect(c.read(libraryViewProvider).mode, LibraryViewMode.cards);
    });
  });

  group('the decode width', () {
    late BuildContext ctx;

    Future<void> host(WidgetTester tester, double dpr) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(devicePixelRatio: dpr),
        child: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );

    testWidgets('the logical width times the screen density', (tester) async {
      await host(tester, 3);
      expect(mtDecodeWidth(ctx, 210), 630);
    });

    /// **The guard**: a 98x62 box is proportionally wider than 16:9, so
    /// `cover` derives its scale from the height. Decoding at 98 alone
    /// gives an image 55 tall stretched to 62, blur we added ourselves.
    testWidgets('the height raises the width when cover demands it', (
      tester,
    ) async {
      await host(tester, 2);
      expect(mtDecodeWidth(ctx, 98, 62), (62 * 16 / 9 * 2).ceil());
      expect(mtDecodeWidth(ctx, 98, 62), greaterThan(98 * 2));
    });

    testWidgets('a box taller than 16:9 does not have its width raised', (
      tester,
    ) async {
      await host(tester, 2);
      expect(mtDecodeWidth(ctx, 300, 62), 600);
    });
  });

  group('the platform chip in the first row', () {
    Widget app(List<LibraryItem> items) => ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        libraryItemsProvider.overrideWith((ref) async => items),
      ],
      child: MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: const Scaffold(body: LibraryFilterChips()),
      ),
    );

    final items = [
      LibraryItem(canonicalUrl: 'https://youtu.be/a', title: 'أ'),
      LibraryItem(canonicalUrl: 'https://vimeo.com/1', title: 'ب'),
    ];

    testWidgets(
      'with no platform selected there is no extra chip, and no third row',
      (tester) async {
        await tester.pumpWidget(app(items));
        await tester.pumpAndSettle();
        expect(find.byType(InputChip), findsNothing);
      },
    );

    /// **The guard**: an active filter hidden behind a button makes the
    /// library look incomplete for no visible reason. The chip is what
    /// makes it visible and cancellable.
    testWidgets('an active platform appears as a chip that one tap removes', (
      tester,
    ) async {
      await tester.pumpWidget(app(items));
      await tester.pumpAndSettle();
      final element = tester.element(find.byType(LibraryFilterChips));
      final container = ProviderScope.containerOf(element);
      container
          .read(libraryViewProvider.notifier)
          .setPlatform(MediaPlatform.youtube);
      await tester.pumpAndSettle();

      expect(find.text('YouTube'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(container.read(libraryViewProvider).platform, isNull);
      expect(find.byType(InputChip), findsNothing);
    });
  });
}
