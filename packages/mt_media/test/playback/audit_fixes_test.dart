import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

/// **حرّاس فحص جهاز المالك 2026-09-05** — كلٌّ منها عن عيب رأيته على
/// الجهاز لا عن احتمال تخيّلته.
void main() {
  const item = PlaylistItem(
    canonicalUrl: 'https://x/a',
    title: 'مقطع بلا غلاف',
    localPath: '/media/a.mp3',
    isAudio: true,
  );

  Widget host(Widget child) => MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.lite, Brightness.light),
        home: Scaffold(body: Center(child: child)),
      );

  group('الوقت المتبقي', () {
    test('معزول الاتجاه فلا يتذيّل السالب', () {
      final text = mtFormatRemaining(
          const Duration(minutes: 10, seconds: 55),
          const Duration(hours: 1, minutes: 1, seconds: 44));
      // الحارس: بلا العزل كانت تُعرض «50:49-» في الواجهة العربية.
      expect(text.startsWith(mtLtrIsolate), isTrue);
      expect(text, contains('-50:49'));
    });

    test('بلا مدة معروفة يبقى الشكل المحايد', () {
      expect(mtFormatRemaining(Duration.zero, null), '--:--');
    });
  });

  group('الغلاف البديل', () {
    testWidgets('باني الغلاف يعيد null ⇒ تظهر الأيقونة البديلة', (
      tester,
    ) async {
      await tester.pumpWidget(host(
        SizedBox(
          width: 200,
          height: 200,
          // **العطل المُبلَّغ عنه**: المزوّد كان يبتلع `null` ويعيد
          // `SizedBox.shrink()`، فيبقى المربع فارغاً تماماً في مشغل
          // الصوت والمشغل المصغر — والأيقونة أدناه كود ميت.
          child: MTTiltedArtwork(item: item, artwork: (_, _) => null),
        ),
      ));
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    });

    testWidgets('غلاف موجود ⇒ يُعرض ولا تظهر الأيقونة', (tester) async {
      await tester.pumpWidget(host(
        SizedBox(
          width: 200,
          height: 200,
          child: MTTiltedArtwork(
            item: item,
            artwork: (_, _) => const ColoredBox(color: Color(0xFF123456)),
          ),
        ),
      ));
      expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);
    });
  });
}
