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

  testWidgets('on its side, the choices leave the subtitle line in view', (
    tester,
  ) async {
    // Visual check 2026-11-10: in the landscape player a bottom sheet hid
    // the subtitle being adjusted, and pushed the background row below the
    // edge of the screen.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(914, 411);
    addTearDown(tester.view.reset);
    final prefs = SubtitlePrefs(MemoryKeyValueStore());
    addTearDown(prefs.dispose);
    for (final language in ['en', 'ar']) {
      await tester.pumpWidget(host(prefs, language: language));
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      final panel = tester.getRect(
        find.byKey(const ValueKey('subtitle-style-panel')),
      );
      // The subtitle sits in the lowest third of the picture.
      expect(panel.bottom, lessThan(411 * 2 / 3), reason: language);
      expect(panel.top, lessThan(411 / 3), reason: language);
      // Both rows are reachable without scrolling.
      final none = language == 'en' ? 'None' : null;
      if (none != null) {
        await tester.tap(find.text(none));
        await tester.pumpAndSettle();
        expect(prefs.liveBackground.value, MTCaptionBackground.none);
      }
      await tester.tapAt(const Offset(457, 400));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('subtitle-style-panel')), findsNothing);
    }
    // The largest text Android allows still fits, by scrolling.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(914, 411),
          textScaler: TextScaler.linear(2),
        ),
        child: host(prefs, language: 'ar'),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
