import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/player/playback_providers.dart';
import 'package:metube_super/features/playlists/widgets/playlist_cards.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

/// **حرّاس فحص جهاز المالك 2026-09-05** — عيبان بصريان رأيتهما على
/// الجهاز، ولكلٍّ جذر في سطر واحد.
void main() {
  Widget host(Widget child, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          locale: const Locale('ar'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('غلاف بطاقة القائمة يملأ ارتفاع الغلاف لا شريطاً وسطه', (
    tester,
  ) async {
    const marker = Key('cover-0');
    await tester.pumpWidget(host(
      SizedBox(
        width: 200,
        height: 260,
        child: PlaylistCard(
          playlist: SavedPlaylist(
            id: 'p1',
            name: 'قائمة',
            items: const [],
            createdAt: DateTime(2026),
          ),
          thumbnails: const [ColoredBox(key: marker, color: Color(0xFF123456))],
          onTap: () {},
          onPlay: () {},
          onLongPress: () {},
        ),
      ),
    ));

    final cover = tester.getSize(find.byKey(marker)).height;
    // الجذر: `Row` افتراضه `center`، فكانت الصورة تأخذ ارتفاعها
    // الطبيعي وتتوسّط — شريط رفيع وسط بطاقة فارغة.
    expect(cover, greaterThan(120),
        reason: 'الغلاف يشغل ما تبقى من البطاقة بعد الاسم والعدّاد');
  });

  testWidgets('باني الغلاف يعيد null لعنصر بلا غلاف — لا ودجت فارغة', (
    tester,
  ) async {
    Widget? built = const SizedBox.shrink();
    await tester.pumpWidget(host(
      Consumer(builder: (context, ref, _) {
        built = artworkBuilderFor(ref)(
          context,
          const PlaylistItem(
            canonicalUrl: 'https://x/a',
            title: 'بلا غلاف',
            localPath: '/media/a.mp3',
            isAudio: true,
          ),
        );
        return const SizedBox.shrink();
      }),
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
      ],
    ));

    // `?? const SizedBox.shrink()` هنا كان يقتل الأيقونة البديلة في
    // مشغل الصوت والمشغل المصغر — مربع أصمّ بلا شيء.
    expect(built, isNull);
  });
}
