import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/library/widgets/server_banner.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Field report 2026-09-13:** "with no internet, Super says it cannot
/// reach the server, which is right, but what about the videos already
/// saved on the phone?"
///
/// `/history` was awaited before the offline index was even read, so any
/// server failure turned the whole library into a full-screen error and
/// hid every offline copy, though each one could still play.
void main() {
  const serverUrl = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
  const localUrl = 'https://www.youtube.com/watch?v=bbbbbbbbbbb';

  HistoryResponse serverList() => HistoryResponse(
    done: const [
      HistoryItem(
        id: 'a',
        canonicalUrl: serverUrl,
        title: 'on the server',
        filename: 'server.mp4',
        status: ItemStatus.completed,
      ),
    ],
  );

  ProviderContainer containerWith(Future<HistoryResponse?> Function() history) {
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        historyProvider.overrideWith((ref) => history()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> saveOnPhone(ProviderContainer c) =>
      c.read(offlineIndexProvider).put(localUrl, '/media/saved.mp4');

  List<String?> titles(List<LibraryItem> items) => [
    for (final item in items) item.title,
  ]..sort((a, b) => (a ?? '').compareTo(b ?? ''));

  group('the library when the server cannot be reached', () {
    test('files on the phone are still the library', () async {
      final c = containerWith(() async => throw const NetworkException('off'));
      await saveOnPhone(c);

      // Guard: on the old code this read threw NetworkException.
      final items = await c.read(libraryItemsProvider.future);

      expect(titles(items), ['saved']);
      expect(items.single.localPath, '/media/saved.mp4');
      expect(c.read(libraryServerErrorProvider), isA<NetworkException>());
    });

    test('nothing on the phone keeps the full-screen error', () async {
      final c = containerWith(() async => throw const NetworkException('off'));

      expect(
        c.read(libraryItemsProvider.future),
        throwsA(isA<NetworkException>()),
      );
    });

    test('a rejected credential is never hidden behind local files', () async {
      final c = containerWith(
        () async => throw const AuthFailureException('401'),
      );
      await saveOnPhone(c);

      expect(
        c.read(libraryItemsProvider.future),
        throwsA(isA<AuthFailureException>()),
      );
    });

    test('a server that drops after a good load keeps its last list', () async {
      var down = false;
      final c = containerWith(() async {
        if (down) throw const NetworkException('dropped');
        return serverList();
      });
      await saveOnPhone(c);
      expect(titles(await c.read(libraryItemsProvider.future)), [
        'on the server',
        'saved',
      ]);
      expect(c.read(libraryServerErrorProvider), isNull);

      down = true;
      c.invalidate(historyProvider);
      final items = await c.read(libraryItemsProvider.future);

      expect(titles(items), ['on the server', 'saved']);
      expect(c.read(libraryServerErrorProvider), isA<NetworkException>());
    });
  });

  group('the banner', () {
    Widget host({
      Object? error = const NetworkException('off'),
      Locale locale = const Locale('ar'),
    }) => ProviderScope(
      overrides: [
        libraryServerErrorProvider.overrideWithValue(error),
        libraryItemsProvider.overrideWith((ref) async => const <LibraryItem>[]),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(MTSpace.pagePad),
            child: LibraryServerBanner(),
          ),
        ),
      ),
    );

    testWidgets('it states the cause, that saved videos play, and a retry', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pump();

      final l10n = await MTLocalizations.delegate.load(const Locale('ar'));
      expect(find.text(l10n.errNetwork), findsOneWidget);
      expect(find.text(l10n.serverUnreachableLocalHint), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
    });

    testWidgets('it is absent while the server answers', (tester) async {
      await tester.pumpWidget(host(error: null));
      await tester.pump();

      final l10n = await MTLocalizations.delegate.load(const Locale('ar'));
      expect(find.text(l10n.serverUnreachableLocalHint), findsNothing);
    });

    testWidgets('device matrix: no overflow in Arabic or English', (
      tester,
    ) async {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        await expectNoOverflow(tester, () => host(locale: locale));
      }
    });
  });
}
