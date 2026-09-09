import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/playlists/widgets/playlist_cards.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// **طلب المالك 2026-09-08**: غلاف القائمة كان خليّتين دائماً، فقائمة
/// من عشرين عنصراً تُعرَّف بغلافين. الآن حتى أربعة، **والتدرّج مقصود**:
/// الواحدة تملأ الغلاف، والثلاث كبيرةٌ واثنتان — لا شبكةٌ فيها ربعٌ فارغ.
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
    theme: mtTheme(MTVariant.superApp, Brightness.light),
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
    testWidgets('$count غلافاً يُبنى بلا فيض', (tester) async {
      await tester.pumpWidget(cardWith(count));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // **الحارس**: أربعة أغلفة تظهر كلها — قبل التعديل كان يُعرض اثنان.
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
