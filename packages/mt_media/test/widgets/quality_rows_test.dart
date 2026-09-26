import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The quality rows in the details sheet** (2026-09-25).
void main() {
  setUp(MTQualityRows.forgetAll);

  Widget host(Widget child, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: Scaffold(body: child),
      );

  Widget row(String label, String value) => Text('$label: $value');

  String strip(String s) =>
      String.fromCharCodes(s.runes.where((r) => r < 0x2066 || r > 0x2069));

  List<String> shown(WidgetTester tester) => [
    for (final w in tester.widgetList<Text>(find.byType(Text)))
      strip(w.data ?? ''),
  ];

  testWidgets('says it is reading, then the owner\'s 4K AV1 clip as it is', (
    tester,
  ) async {
    final answer = Completer<MediaQuality?>();
    await tester.pumpWidget(
      host(
        MTQualityRows(
          cacheKey: 'https://x/4k',
          load: () => answer.future,
          row: row,
          // 293 MB over 7.1 minutes, measured on a real server.
          sizeBytes: 293000000,
          duration: const Duration(minutes: 7, seconds: 6),
        ),
      ),
    );
    expect(shown(tester), ['Video: Reading the file…']);

    answer.complete(
      const MediaQuality(
        width: 3840,
        height: 2160,
        videoMime: 'video/av01',
        frameRate: 60,
        audioMime: 'audio/opus',
        channels: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(shown(tester), [
      'Video: 4K · 3840×2160 · AV1 · 60 fps · 5.5 Mb/s',
      'Audio: Opus · Stereo',
    ]);
  });

  testWidgets('an audio-only file shows its audio, with the bitrate there', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        MTQualityRows(
          cacheKey: 'https://x/song',
          load: () async =>
              const MediaQuality(audioMime: 'audio/mp4a-latm', channels: 2),
          row: row,
          sizeBytes: 3840000,
          duration: const Duration(minutes: 4),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(shown(tester), ['Audio: AAC · Stereo · 128 kb/s']);
  });

  testWidgets('a header that cannot be read says so, and is asked again next '
      'time rather than remembered', (tester) async {
    var asks = 0;
    Widget sheet() => host(
      MTQualityRows(
        cacheKey: 'https://x/down',
        load: () async {
          asks++;
          throw StateError('server down');
        },
        row: row,
      ),
    );
    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();
    expect(shown(tester), ['Video: Unavailable']);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();
    expect(asks, 2);
  });

  testWidgets('a clip read once is not read again this run', (tester) async {
    var asks = 0;
    Widget sheet() => host(
      MTQualityRows(
        cacheKey: 'https://x/once',
        load: () async {
          asks++;
          return const MediaQuality(
            videoMime: 'video/avc',
            width: 1920,
            height: 1080,
          );
        },
        row: row,
      ),
    );
    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(sheet());
    await tester.pumpAndSettle();

    expect(asks, 1);
    expect(shown(tester), ['Video: 1080p · 1920×1080 · H.264']);
  });

  testWidgets('in Arabic the words are Arabic and the names stay whole', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        MTQualityRows(
          cacheKey: 'https://x/ar',
          load: () async => const MediaQuality(
            width: 1080,
            height: 1920,
            videoMime: 'video/x-vnd.on2.vp9',
            frameRate: 30,
            audioMime: 'audio/opus',
            channels: 2,
          ),
          row: row,
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(shown(tester), [
      'الفيديو: 1080p · 1080×1920 · VP9 · 30 إطار/ث',
      'الصوت: Opus · ستيريو',
    ]);
  });
}
