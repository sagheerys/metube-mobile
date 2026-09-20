import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

/// **An empty square where a cover should be** (field report 2026-09-20:
/// "an audio clip inside the video player's queue shows a black square").
///
/// The tile asked the app for a cover and drew its own icon only when the
/// answer was null. But the app answers null only for an item with **no**
/// cover at all; a cover that exists and then fails to load — a cleared
/// cache, an extracted cover deleted with the file, a server thumbnail that
/// 404s — comes back as an empty box, and an empty box on the dark queue
/// sheet is a black square with nothing in it.
PlaylistItem _item({required bool isAudio}) => PlaylistItem(
  canonicalUrl: 'https://x/a',
  title: 'clip',
  serverFilename: 'a.mp4',
  isAudio: isAudio,
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required MTArtworkBuilder? artwork,
    bool isAudio = true,
    bool dark = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        home: Scaffold(
          body: MTUpNextList(
            items: [_item(isAudio: isAudio)],
            currentIndex: 0,
            dark: dark,
            artwork: artwork,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a cover that fails to load leaves the icon showing, not an '
      'empty square', (tester) async {
    // Exactly what `artworkFor` does when an image errors.
    await pump(tester, artwork: (_, _) => const SizedBox.shrink());

    expect(
      find.byIcon(Icons.music_note_rounded),
      findsOneWidget,
      reason: 'قبل الإصلاح كان المربّع يخلو تماماً فيُقرأ أسود',
    );
  });

  testWidgets('and so does no cover at all', (tester) async {
    await pump(tester, artwork: (_, _) => null);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });

  testWidgets('with no builder at all', (tester) async {
    await pump(tester, artwork: null);
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
  });

  testWidgets('a video with no cover gets the video icon', (tester) async {
    await pump(tester, artwork: null, isAudio: false);
    expect(find.byIcon(Icons.movie_rounded), findsOneWidget);
    expect(find.byIcon(Icons.music_note_rounded), findsNothing);
  });

  testWidgets('a cover that does load covers the icon rather than sitting '
      'beside it', (tester) async {
    await pump(
      tester,
      artwork: (_, _) => const ColoredBox(color: Color(0xFF00FF00)),
    );

    final stack = tester.widget<Stack>(
      find
          .ancestor(
            of: find.byType(ColoredBox).first,
            matching: find.byType(Stack),
          )
          .first,
    );
    // The cover is last, so it paints over the icon and fills the box.
    expect(stack.children.last, isA<ColoredBox>());
    expect(stack.fit, StackFit.expand);
  });
}
