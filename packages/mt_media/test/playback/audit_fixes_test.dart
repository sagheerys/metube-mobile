import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **Guards from a device review on 2026-09-05**: each one is about a flaw
/// seen on the device rather than an imagined possibility.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlatform());

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
        const Duration(hours: 1, minutes: 1, seconds: 44),
      );
      // The guard: without isolation the Arabic interface rendered
      // "50:49-".
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
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 200,
            height: 200,
            // **The reported defect**: the provider swallowed `null` and
            // returned `SizedBox.shrink()`, so the square stayed completely
            // blank in the audio player and the mini player, and the
            // fallback icon below it was dead code.
            child: MTTiltedArtwork(item: item, artwork: (_, _) => null),
          ),
        ),
      );
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    });

    testWidgets('غلاف موجود ⇒ يُعرض ولا تظهر الأيقونة', (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 200,
            height: 200,
            child: MTTiltedArtwork(
              item: item,
              artwork: (_, _) => const ColoredBox(color: Color(0xFF123456)),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);
    });
  });

  group('المشغل عرضياً (بلاغ المالك 2026-09-05)', () {
    testWidgets('الخروج من الملء التام والجهاز عرضي ⇒ الفيديو يملأ الشاشة', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 2880);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final session = MTVideoSession(
        resolver: PlaybackSourceResolver(
          endpoint: ServerStreamEndpoint.none,
          fileExists: (_) => true,
        ),
        positions: PlaybackPositionStore(
          store: MemoryKeyValueStore(),
          mutex: PrefsMutex(),
        ),
        prefs: PlaybackPrefs(store: MemoryKeyValueStore(), mutex: PrefsMutex()),
        saveInterval: const Duration(hours: 1),
      );
      await tester.runAsync(
        () => session.open(const [
          PlaylistItem(
            canonicalUrl: 'https://x/a',
            title: 'مقطع',
            localPath: '/media/a.mp4',
          ),
        ]),
      );

      final navKey = GlobalKey<NavigatorState>();
      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          locale: const Locale('ar'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(MTVariant.lite, Brightness.light),
          home: MTVideoScreen(session: session),
        ),
      );
      await settle();
      expect(
        find.byType(MTVideoInfoSheet, skipOffstage: false),
        findsOneWidget,
        reason: 'ضابط: طولياً الورقة موجودة',
      );

      // A tilt opens full screen automatically.
      tester.view.physicalSize = const Size(2880, 1440);
      await settle();
      expect(
        find.byType(MTVideoFullscreenPage, skipOffstage: false),
        findsOneWidget,
      );

      // Leaving by the button with the device still in landscape: this is
      // where a portrait layout appeared on a wide screen (field report).
      navKey.currentState!.pop();
      await settle();
      expect(
        find.byType(MTVideoFullscreenPage, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byType(MTVideoInfoSheet, skipOffstage: false),
        findsNothing,
        reason: 'الورقة الكريمية لا مكان لها في شاشة عريضة',
      );

      await tester.runAsync(session.dispose);
    });
  });
}
