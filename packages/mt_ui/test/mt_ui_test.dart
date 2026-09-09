import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

void main() {
  group('mtTheme: the surfaceContainer* lesson', () {
    for (final variant in MTVariant.values) {
      for (final brightness in Brightness.values) {
        test(
          '${variant.name}/${brightness.name}: the five roles are assigned and distinct',
          () {
            final scheme = mtTheme(variant, brightness).colorScheme;
            final ramp = {
              scheme.surfaceContainerLowest,
              scheme.surfaceContainerLow,
              scheme.surfaceContainer,
              scheme.surfaceContainerHigh,
              scheme.surfaceContainerHighest,
            };
            expect(
              ramp,
              hasLength(5),
              reason: 'أي تطابق يعني سقوطاً لرماديات M3 الافتراضية',
            );
            expect(scheme.surface, MTPalette.of(variant, brightness).bg);
          },
        );
      }
    }

    test(
      'the accent colour: the warm glow for Super and the teal for Lite',
      () {
        expect(
          mtTheme(MTVariant.superApp, Brightness.light).colorScheme.primary,
          const Color(0xFFC25E2E),
        );
        expect(
          mtTheme(MTVariant.superApp, Brightness.dark).colorScheme.primary,
          const Color(0xFFE0784A),
        );
        expect(
          mtTheme(MTVariant.lite, Brightness.light).colorScheme.primary,
          const Color(0xFF2F6D74),
        );
        expect(
          mtTheme(MTVariant.lite, Brightness.dark).colorScheme.primary,
          const Color(0xFF6FB3BA),
        );
      },
    );

    test('at night, text over the accent is dark, not white', () {
      for (final variant in MTVariant.values) {
        final onAccent = MTPalette.of(variant, Brightness.dark).onAccent;
        expect(onAccent.computeLuminance(), lessThan(0.1));
      }
    });

    test(
      'the favourite is a crimson of its own, independent of both accents',
      () {
        for (final variant in MTVariant.values) {
          final p = MTPalette.of(variant, Brightness.light);
          expect(p.favorite, const Color(0xFFA83A3A));
          expect(p.favorite, isNot(p.accent));
        }
      },
    );
  });

  group('MTGalleryScreen', () {
    Widget host(
      MTVariant variant,
      Brightness brightness,
      TextDirection direction,
    ) => MaterialApp(
      theme: mtTheme(variant, brightness),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      locale: Locale(direction == TextDirection.rtl ? 'ar' : 'en'),
      home: Directionality(
        textDirection: direction,
        child: const MTGalleryScreen(),
      ),
    );

    for (final variant in MTVariant.values) {
      for (final brightness in Brightness.values) {
        for (final direction in TextDirection.values) {
          testWidgets(
            'it draws without error: ${variant.name}/${brightness.name}/${direction.name}',
            (tester) async {
              // A tall surface, so every section of the lazy list is actually
              // built.
              tester.view.physicalSize = const Size(800, 3600);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              await tester.pumpWidget(host(variant, brightness, direction));
              await tester.pump(const Duration(milliseconds: 50));
              expect(tester.takeException(), isNull);
              expect(find.byType(MTGalleryScreen), findsOneWidget);
              expect(find.byType(MTMediaCard), findsWidgets);
              expect(find.byType(MTDownloadProgressCard), findsNWidgets(2));
            },
          );
        }
      }
    }
  });

  group('MTMediaCard', () {
    testWidgets('tapping the heart calls the toggle', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          // The card reads localisations for its button tooltips and its
          // screen-reader description (audit 8.1), so it needs the delegates
          // like any real screen.
          locale: const Locale('ar'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: Scaffold(
            body: MTMediaCard(
              title: 'عنوان',
              favorite: true,
              onFavoriteToggle: () => toggled = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      expect(toggled, isTrue);
    });
  });

  group('MTLocalizations', () {
    test('Arabic and English are both supported', () {
      expect(
        MTLocalizations.supportedLocales.map((l) => l.languageCode),
        containsAll(['ar', 'en']),
      );
    });

    /// **Caught by hand on a device, 2026-09-08**: the delete-playlist
    /// dialog showed two visible backslashes around the playlist name,
    /// because the quote in the arb file was written as an escaped
    /// backslash-quote and JSON unescaped it into a backslash followed by a
    /// quote. Neither `analyze` nor the parity guard catches it: the JSON
    /// is valid and the key is translated in both languages. **Only the eye
    /// sees it**, and this guard now stands in for the eye.
    test('no stray slash visible in the confirmation strings', () async {
      for (final code in ['ar', 'en']) {
        final l10n = await MTLocalizations.delegate.load(Locale(code));
        for (final text in [
          l10n.deletePlaylistConfirm('س'),
          l10n.deleteVideoConfirm('س'),
          l10n.deleteTagConfirm('س'),
        ]) {
          expect(text, isNot(contains(r'\')), reason: '[$code] $text');
        }
      }
    });
  });
}
