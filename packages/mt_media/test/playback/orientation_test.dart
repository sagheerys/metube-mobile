import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **حرّاس التدوير (قرار المالك 2026-09-05)**: التطبيق طولي والمشغل
/// وحده يدور — والإمالة تفتح الملء التام وتغلقه.
///
/// العطل الأصلي: `dispose` الملء التام كان يقفل `portraitUp` **على
/// التطبيق كله وإلى الأبد** (الأمر عام لا يخصّ الشاشة التي نادته)،
/// فبعد أول فيديو ملء الشاشة لا يدور شيء حتى يُقتل التطبيق.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<List<String>> locks;

  setUp(() {
    locks = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        locks.add(List<String>.from(call.arguments as List));
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  bool isPortraitLock(List<String> lock) =>
      lock.length == 1 && lock.single.endsWith('portraitUp');
  bool isLandscapeLock(List<String> lock) =>
      lock.length == 2 && lock.every((o) => o.contains('landscape'));
  bool isFree(List<String> lock) => lock.length == 3;

  /// مضيف يتحكم بالاتجاه عبر مقاس الشاشة — `Orientation` مشتق منه.
  Widget host({required Size size, required Widget child}) => MediaQuery(
        data: MediaQueryData(size: size),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => child),
          ),
        ),
      );

  const portrait = Size(400, 800);
  const landscape = Size(800, 400);

  group('MTRotationScope', () {
    testWidgets('إمالة الجهاز تفتح الملء التام مرة واحدة', (tester) async {
      var opened = 0;
      Widget scope(Size size) => host(
            size: size,
            child: MTRotationScope(
              open: (byRotation) async {
                opened++;
                expect(byRotation, isTrue);
              },
              builder: (_, _) => const SizedBox.shrink(),
            ),
          );

      await tester.pumpWidget(scope(portrait));
      expect(opened, 0);

      await tester.pumpWidget(scope(landscape));
      await tester.pump();
      expect(opened, 1);

      // إطارات إضافية بنفس الاتجاه لا تفتح شيئاً جديداً.
      await tester.pumpWidget(scope(landscape));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('خروج يدوي والجهاز عرضي ⇒ لا يُعاد الفتح فوراً', (
      tester,
    ) async {
      var opened = 0;
      Widget scope(Size size) => host(
            size: size,
            child: MTRotationScope(
              // الملء التام أُغلق فوراً — كأن المستخدم ضغط الخروج.
              open: (_) async => opened++,
              builder: (_, _) => const SizedBox.shrink(),
            ),
          );

      await tester.pumpWidget(scope(landscape));
      await tester.pump();
      expect(opened, 1);

      // الحلقة التي يحرسها هذا: يخرج فيرى النطاقُ الجهازَ عرضياً
      // فيفتح، فيخرج، فيفتح… إلى ما لا نهاية.
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(scope(landscape));
        await tester.pump();
      }
      expect(opened, 1);

      // العودة للطولي تعيد التسليح، والإمالة التالية تفتح من جديد.
      await tester.pumpWidget(scope(portrait));
      await tester.pump();
      await tester.pumpWidget(scope(landscape));
      await tester.pump();
      expect(opened, 2);
    });

    testWidgets('الزر يفتح بلا إمالة ويخبر الصفحة أنه ليس تدويراً', (
      tester,
    ) async {
      bool? byRotation;
      late VoidCallback press;
      await tester.pumpWidget(host(
        size: portrait,
        child: MTRotationScope(
          open: (r) async => byRotation = r,
          builder: (_, open) {
            press = open;
            return const SizedBox.shrink();
          },
        ),
      ));

      press();
      await tester.pump();
      expect(byRotation, isFalse);
    });

    testWidgets('يفكّ القفل عند الدخول ويعيده عند المغادرة', (tester) async {
      await tester.pumpWidget(host(
        size: portrait,
        child: MTRotationScope(
          open: (_) async {},
          builder: (_, _) => const SizedBox.shrink(),
        ),
      ));
      expect(locks.where(isFree).length, 1,
          reason: 'المشغل مفتوح ⇒ التدوير مسموح');

      // شجرة أخرى بالكامل — تبديل `child` داخل نفس `Navigator` لا
      // يعيد بناء مساره القائم، فلا يُصرَّف النطاق أصلاً.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      // الحارس: القفل يعود عند مغادرة المشغل لا قبلها ولا أبداً.
      expect(locks.any(isPortraitLock), isTrue);
    });
  });

  group('MTOrientation', () {
    test('الطولي وحده لا يشمل المقلوب', () {
      expect(MTOrientation.portrait, [DeviceOrientation.portraitUp]);
      expect(MTOrientation.free.contains(DeviceOrientation.portraitDown),
          isFalse);
    });

    testWidgets('lockLandscape يرسل العرضيين وحدهما', (tester) async {
      await MTOrientation.lockLandscape();
      expect(locks.single, predicate<List<String>>(isLandscapeLock));
    });
  });

  group('المشغل الحقيقي — العطل المُبلَّغ عنه', () {
    setUp(() => VideoPlayerPlatform.instance = FakeVideoPlatform());

    MTVideoSession newSession() {
      final store = MemoryKeyValueStore();
      final mutex = PrefsMutex();
      return MTVideoSession(
        resolver: PlaybackSourceResolver(
          endpoint: ServerStreamEndpoint.none,
          fileExists: (_) => true,
        ),
        positions: PlaybackPositionStore(store: store, mutex: mutex),
        prefs: PlaybackPrefs(store: store, mutex: mutex),
        saveInterval: const Duration(hours: 1),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('الخروج من الملء التام لا يثبّت التطبيق على الطولي', (
      tester,
    ) async {
      // **سطح الاختبار طولي**: افتراضه 800×600 أي عرضي، فينفتح الملء
      // التام بالإمالة قبل أن نضغط الزر ونحن نحرس مسار الزر.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final session = newSession();
      await tester.runAsync(() => session.open(const [
            PlaylistItem(
              canonicalUrl: 'https://x/a',
              title: 'a',
              localPath: '/media/a.mp4',
            ),
          ]));
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: const Scaffold(body: Center(child: Text('BASE'))),
      ));
      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => MTVideoScreen(session: session),
      )));
      await settle(tester);
      expect(locks.last, predicate<List<String>>(isFree),
          reason: 'المشغل مفتوح ⇒ الدوران مسموح');

      // الدخول بالزر يفرض العرضي (قافل التدوير لا يستطيع الإمالة).
      // يُستدعى الفعل مباشرة لا بلمسة: الأدوات تختفي وحدها بمؤقت،
      // فاللمسة تصير رهينة توقيت لا علاقة له بما نحرسه.
      tester
          .widget<MTVideoTopBar>(find.byType(MTVideoTopBar).first)
          .onToggleFullscreen();
      await settle(tester);
      expect(locks.last, predicate<List<String>>(isLandscapeLock));

      navKey.currentState!.pop();
      await settle(tester);
      // **الحارس**: كان هنا `portraitUp` — أمرٌ عام على التطبيق كله لا
      // ينتهي بإغلاق الصفحة، فلا يدور شيء بعدها حتى يُقتل التطبيق.
      expect(locks.last, predicate<List<String>>(isFree));

      navKey.currentState!.pop();
      await settle(tester);
      expect(locks.last, predicate<List<String>>(isPortraitLock),
          reason: 'مغادرة المشغل ⇒ يعود قفل التطبيق الطولي');
      await tester.runAsync(session.dispose);
    });
  });
}
