import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/library_providers.dart';
import 'package:metube_lite/features/downloads_library/library_screen.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:metube_lite/features/downloads_library/media_access.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **The whole library on every shape (2026-10-10)**, the twin of Super's:
/// each view mode, in both languages, across the device matrix's phones,
/// tablets and foldables and its three font scales.
void main() {
  const titles = [
    'Homelab Hour — Ep. 12: Backups that actually restore, and the ones that do not',
    'رحلة إلى جبال السروات في موسم الضباب مع عدسة الجنوب',
    'Amber Skies',
    'القهوة السعودية: الطريقة الكاملة من التحميص إلى التقديم',
  ];

  final items = [
    for (var i = 0; i < 12; i++)
      LocalItem(
        key: 'https://www.youtube.com/watch?v=item$i',
        canonicalUrl: 'https://www.youtube.com/watch?v=item$i',
        path:
            '/storage/emulated/0/Download/MeTube/item$i.'
            '${i % 3 == 0 ? 'mp3' : 'mp4'}',
        title: titles[i % titles.length],
        sizeBytes: 1000000 * (i + 1) * 37,
        modified: DateTime(2026, 10, 10).subtract(Duration(hours: i * 7)),
        duration: Duration(minutes: i, seconds: 42),
      ),
  ];

  Future<Widget Function()> hostFor(LibraryViewMode mode, Locale locale) async {
    final store = MemoryKeyValueStore();
    await store.setString('library_view_mode', mode.name);
    return () {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(
            const LiteSettings(serverUrl: 'http://nas.local:8081'),
          ),
          mediaAccessGateProvider.overrideWithValue(
            MediaAccessGate(
              probe: () async => true,
              isGranted: (_) async => true,
              ask: (_) async => true,
            ),
          ),
          localMediaProvider.overrideWith((ref) async => items),
        ],
      );
      addTearDown(container.dispose);
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(MTVariant.lite, Brightness.light),
          home: const LibraryScreen(),
        ),
      );
    };
  }

  for (final mode in LibraryViewMode.values) {
    testWidgets('**device matrix**: the ${mode.name} mode never overflows', (
      tester,
    ) async {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        final host = await tester.runAsync(() => hostFor(mode, locale));
        await expectNoOverflow(tester, host!);
      }
    });
  }

  testWidgets('the items really are on screen, not an empty state', (
    tester,
  ) async {
    final host = await tester.runAsync(
      () => hostFor(LibraryViewMode.list, const Locale('en')),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host!());
    await tester.pumpAndSettle();
    expect(find.byType(MTMediaRow), findsWidgets);
  });
}
