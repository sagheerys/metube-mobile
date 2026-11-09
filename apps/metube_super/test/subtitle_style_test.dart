import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/transcripts/subtitle_style.dart';
import 'package:metube_super/features/transcripts/subtitles.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// The subtitles' size and background, changed over the playing clip from
/// a long press on CC (owner's request 2026-11-10), as well as in settings.
void main() {
  Widget host(
    SubtitlePrefs prefs, {
    String language = 'en',
    Brightness brightness = Brightness.light,
  }) => MaterialApp(
    locale: Locale(language),
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    theme: mtTheme(MTVariant.superApp, brightness),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showSubtitleStyleSheet(context, prefs),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ),
  );

  testWidgets('a choice in the sheet reaches the playing clip at once', (
    tester,
  ) async {
    final prefs = SubtitlePrefs(MemoryKeyValueStore());
    addTearDown(prefs.dispose);
    await tester.pumpWidget(host(prefs));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.text('Text size'), findsOneWidget);

    await tester.tap(find.text('Large'));
    await tester.pumpAndSettle();
    expect(prefs.size.value, 2);
    expect(prefs.liveScale.value, SubtitlePrefs.scales[2]);

    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    expect(prefs.liveBackground.value, MTCaptionBackground.none);
  });

  testWidgets('the sheet holds on every device, language and theme', (
    tester,
  ) async {
    for (final language in ['en', 'ar']) {
      for (final brightness in Brightness.values) {
        final prefs = SubtitlePrefs(MemoryKeyValueStore());
        addTearDown(prefs.dispose);
        await expectNoOverflow(tester, () {
          return host(prefs, language: language, brightness: brightness);
        });
      }
    }
    // The sheet itself, open, on the smallest phone at the largest text.
    final prefs = SubtitlePrefs(MemoryKeyValueStore());
    addTearDown(prefs.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: host(prefs, language: 'ar'),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
