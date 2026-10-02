import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The music-note mark on an audio item's thumbnail** (field report 2026-09-29):
/// an audio file from a video site keeps the video's frame as its cover, so
/// nothing on the card told a song from a video.
void main() {
  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: mtTheme(MTVariant.superApp, brightness),
        home: Scaffold(
          body: Center(child: SizedBox(width: 360, child: child)),
        ),
      );

  const cover = ColoredBox(color: Colors.teal);
  final note = find.byIcon(Icons.music_note_rounded);

  final cards = <String, Widget Function({required bool audio, Widget? art})>{
    'list card': ({required audio, art}) =>
        MTMediaCard(title: 'Song', thumbnail: art, audio: audio),
    'compact card': ({required audio, art}) =>
        MTMediaCard(title: 'Song', thumbnail: art, audio: audio, compact: true),
    'grid card': ({required audio, art}) =>
        MTMediaGridCard(title: 'Song', thumbnail: art, audio: audio),
    'feed card': ({required audio, art}) => MTMediaGridCard(
      title: 'Song',
      thumbnail: art,
      audio: audio,
      feed: true,
    ),
  };

  for (final MapEntry(key: name, value: card) in cards.entries) {
    group(name, () {
      testWidgets('an audio item with a cover carries the mark', (
        tester,
      ) async {
        await tester.pumpWidget(host(card(audio: true, art: cover)));
        expect(note, findsOneWidget);
      });

      testWidgets('a video with a cover carries none', (tester) async {
        await tester.pumpWidget(host(card(audio: false, art: cover)));
        expect(note, findsNothing);
      });

      testWidgets('without a cover the placeholder note is not doubled', (
        tester,
      ) async {
        await tester.pumpWidget(host(card(audio: true)));
        expect(note, findsOneWidget);
      });

      testWidgets('a screen reader hears that it is audio', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(host(card(audio: true, art: cover)));
        expect(find.bySemanticsLabel(RegExp(r'Song.*Audio')), findsOneWidget);
        handle.dispose();
      });
    });
  }

  // The grid cover is where both apps show a duration; the list modes pass
  // none. A two-column grid cell is the narrowest cover that carries one.
  testWidgets('the mark sits beside the duration without overlapping it', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 170,
          child: MTMediaGridCard(
            title: 'Song',
            thumbnail: cover,
            duration: '1:02:45',
            audio: true,
          ),
        ),
      ),
    );
    final mark = tester.getRect(note);
    final time = tester.getRect(find.text('1:02:45'));
    expect(mark.overlaps(time), isFalse);
  });

  testWidgets('at night the mark keeps the duration pill colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const MTMediaCard(title: 'Song', thumbnail: cover, audio: true),
        brightness: Brightness.dark,
      ),
    );
    final icon = tester.widget<Icon>(note);
    expect(
      icon.color,
      MTPalette.of(MTVariant.superApp, Brightness.dark).bg,
      reason: 'a fixed colour would vanish against the night palette',
    );
  });
}
