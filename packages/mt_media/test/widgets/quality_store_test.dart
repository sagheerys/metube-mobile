import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The details sheet read the file's header on every launch** (reported
/// 2026-09-29): the answer lived in memory alone, so each new session paid
/// the server round trip again and showed "reading" meanwhile. These guard
/// the store that keeps it.
void main() {
  late MediaQualityIndex index;

  setUp(() {
    MTQualityRows.forgetAll();
    index = MediaQualityIndex(
      store: MemoryKeyValueStore(),
      mutex: PrefsMutex(),
    );
  });

  const fourK = MediaQuality(
    width: 3840,
    height: 2160,
    videoMime: 'video/av01',
    frameRate: 60,
    audioMime: 'audio/opus',
    sampleRate: 48000,
    channels: 2,
  );
  const url = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';

  group('MediaQualityIndex', () {
    test('an answer survives the round trip whole', () async {
      await index.remember(url, fourK);
      final back = await index.valueOf(url);
      expect(back?.toMap(), fourK.toMap());
    });

    test('an empty answer is not stored', () async {
      await index.remember(url, const MediaQuality());
      expect(await index.readAll(), isEmpty);
    });

    test('a missing field stays missing, not zero', () async {
      await index.remember(url, const MediaQuality(audioMime: 'audio/opus'));
      final back = await index.valueOf(url);
      expect(back?.width, isNull);
      expect(back?.hasVideo, isFalse);
    });
  });

  group('MTQualityRows with a store', () {
    Widget host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      home: Scaffold(body: child),
    );

    Widget row(String label, String value) => Text('$label: $value');

    testWidgets('a stored answer is shown without reading the header', (
      tester,
    ) async {
      await index.remember(url, fourK);
      var asks = 0;
      await tester.pumpWidget(
        host(
          MTQualityRows(
            cacheKey: url,
            store: index,
            row: row,
            load: () async {
              asks++;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(asks, 0, reason: 'the stored answer replaces the round trip');
      expect(find.textContaining('4K'), findsOneWidget);
    });

    testWidgets('a header read once is stored for the next launch', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          MTQualityRows(
            cacheKey: url,
            store: index,
            row: row,
            load: () async => fourK,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A new launch: this run's memory is gone, the store is not.
      MTQualityRows.forgetAll();
      expect((await index.valueOf(url))?.resolutionLabel, '4K');
    });

    testWidgets('a failed read is not stored, so the next opening retries', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          MTQualityRows(
            cacheKey: url,
            store: index,
            row: row,
            load: () async => throw StateError('server down'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Video: Unavailable'), findsOneWidget);
      expect(await index.readAll(), isEmpty);
    });
  });
}
