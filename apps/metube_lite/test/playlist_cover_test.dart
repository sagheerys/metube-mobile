import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/features/playlists/widgets/playlist_cards.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Requested 2026-09-08**: a playlist cover was always two cells, so a
/// playlist of twenty items was represented by two covers. Now it goes up
/// to four, **and the progression is deliberate**: one fills the cover, and
/// three means one large and two small, rather than a grid with an empty
/// quarter.
void main() {
  SavedPlaylist playlistOf(int items) => SavedPlaylist(
    id: 'p1',
    name: 'قائمة',
    items: [
      for (var i = 0; i < items; i++)
        PlaylistEntry(canonicalUrl: 'https://x/$i'),
    ],
  );

  Widget cardWith(int covers) => MaterialApp(
    theme: mtTheme(MTVariant.lite, Brightness.light),
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 180,
        height: 220,
        child: PlaylistCard(
          playlist: playlistOf(covers),
          thumbnails: [
            for (var i = 0; i < covers; i++)
              ColoredBox(key: ValueKey('cover$i'), color: Colors.red),
          ],
          onTap: () {},
          onPlay: () {},
          onLongPress: () {},
        ),
      ),
    ),
  );

  for (final count in [0, 1, 2, 3, 4, 6]) {
    testWidgets('$count covers build without overflowing', (tester) async {
      await tester.pumpWidget(cardWith(count));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // **The guard**: all four covers appear; before the change two were
      // shown.
      final shown = count > 4 ? 4 : count;
      for (var i = 0; i < shown; i++) {
        expect(
          find.byKey(ValueKey('cover$i')),
          findsOneWidget,
          reason: 'الغلاف $i من $count',
        );
      }
      if (count > 4) {
        expect(
          find.byKey(const ValueKey('cover4')),
          findsNothing,
          reason: 'الخامس لا مكان له',
        );
      }
    });
  }
}
