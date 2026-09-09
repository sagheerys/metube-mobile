import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/downloads_library/library_providers.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:metube_lite/features/downloads_library/widgets/library_chips.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// A test shell in Lite's identity with its localisations, and with no
/// server and no audio.
Widget host(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: mtTheme(MTVariant.lite, Brightness.light),
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

LocalItem sample(String name, {MediaPlatform? platform}) => LocalItem(
  key: platform == MediaPlatform.youtube
      ? 'https://youtu.be/$name'
      : '$liteMediaDir/$name.mp4',
  path: '$liteMediaDir/$name.mp4',
  canonicalUrl: platform == MediaPlatform.youtube
      ? 'https://youtu.be/$name'
      : null,
  title: name,
  sizeBytes: 10,
  modified: DateTime(2026),
);

void main() {
  final store = MemoryKeyValueStore();

  List<Override> base(List<LocalItem> items) => [
    keyValueStoreProvider.overrideWithValue(store),
    secretStoreProvider.overrideWithValue(MemorySecretStore()),
    initialSettingsProvider.overrideWithValue(const LiteSettings()),
    localMediaProvider.overrideWith((ref) async => items),
  ];

  testWidgets('رقائق المنصة تختفي حين المكتبة منصة واحدة (م-14)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const PlatformFilterChips(),
        overrides: base([sample('a'), sample('b')]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('رقائق المنصة تظهر بعدادات حية عند تعدد المنصات', (tester) async {
    await tester.pumpWidget(
      host(
        const PlatformFilterChips(),
        overrides: base([
          sample('a'),
          sample('b', platform: MediaPlatform.youtube),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    // "All platforms" plus one chip per platform actually present.
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.textContaining('1'), findsWidgets);
  });

  testWidgets('صف المرشحات يعرض المفضلة والقِصار (م-35/م-36)', (tester) async {
    await tester.pumpWidget(
      host(const LibraryFilterChips(), overrides: base([sample('a')])),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('♥'), findsOneWidget);
    expect(find.textContaining('⚡'), findsOneWidget);
  });
}
