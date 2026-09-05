import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **انحدار ميداني مُستنسخ على المحاكي (2026-09-03).**
///
/// بلاغ المالك: «عند الرجوع تظهر رسالة متابعة بالخلفية، وبالضغط على
/// متابعة صوتاً يشتغل الصوت **ويبقى في نفس الشاشة**… وعند إيقاف المقطع
/// في الميني بلاير يتوقف التطبيق كلياً وتظهر شاشة سوداء».
///
/// السبب: `just_audio.play()` — بنصّ الحزمة — «يكتمل حين ينتهي التشغيل
/// أو يُوقَف». فانتظاره علّق النقل، فلم تُغلق الشاشة؛ ثم عند الإيقاف
/// اكتمل المستقبل فنُفِّذ `pop` المؤجل — والمستخدم قد غادر — **فأسقط
/// الغلاف نفسه**. هنا يُحرَس الطرفان: بطء النقل، وحرمة صفحة غيرنا.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlatform platform;

  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

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

  const item = PlaylistItem(
    canonicalUrl: 'https://x/a',
    title: 'a',
    localPath: '/media/a.mp4',
  );

  /// **لا `pumpAndSettle`**: الشاشة تحوي مؤشرات دائمة الحركة (مكافئ
  /// «يشغَّل الآن»)، فالاستقرار لا يقع أبداً.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// **سطح الاختبار طولي كالهاتف.** الافتراضي 800×600 أي *عرضي*،
  /// ومنذ 2026-09-05 صار المشغل يفتح الملء التام عند الإمالة — فكانت
  /// هذه الاختبارات تبدأ داخل الملء التام بلا أن تقصده.
  void usePhonePortrait(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> openPlayer(
    WidgetTester tester,
    GlobalKey<NavigatorState> navKey,
    MTVideoSession session,
    Future<void> Function(PlaylistItem, Duration) onContinueAsAudio,
  ) async {
    usePhonePortrait(tester);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      home: const Scaffold(body: Center(child: Text('BASE'))),
    ));
    unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => MTVideoScreen(
        session: session,
        onContinueAsAudio: onContinueAsAudio,
      ),
    )));
    await settle(tester);
  }

  testWidgets('نقلٌ بطيء لا يُسقط الغلاف بعد أن يغادر المستخدم بطريق آخر',
      (tester) async {
    final session = newSession();
    await tester.runAsync(() => session.open([item]));
    final transfer = Completer<void>();
    final navKey = GlobalKey<NavigatorState>();
    await openPlayer(tester, navKey, session, (_, _) => transfer.future);

    // الرجوع ⇒ حوار «متابعة بالخلفية؟» ⇒ «متابعة صوتاً».
    unawaited(navKey.currentState!.maybePop());
    await settle(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('BASE'), findsNothing, reason: 'النقل لم يكتمل بعد');

    // المستخدم يغادر بنفسه (الضغطة الثانية في البلاغ).
    navKey.currentState!.pop();
    await settle(tester);
    expect(find.text('BASE'), findsOneWidget);

    // ثم يكتمل النقل متأخراً — عند إيقاف الصوت في المشغل المصغر.
    transfer.complete();
    await settle(tester);

    expect(find.text('BASE'), findsOneWidget,
        reason: 'pop عمياء كانت تُسقط الغلاف ⇒ شاشة سوداء');
    await tester.runAsync(session.dispose);
  });

  testWidgets('النقل السريع يُغلق الشاشة كالمعتاد', (tester) async {
    final session = newSession();
    await tester.runAsync(() => session.open([item]));
    var transferred = 0;
    final navKey = GlobalKey<NavigatorState>();
    await openPlayer(tester, navKey, session, (_, _) async => transferred++);

    unawaited(navKey.currentState!.maybePop());
    await settle(tester);
    await tester.tap(find.byType(FilledButton));
    await settle(tester);

    expect(transferred, 1);
    expect(find.text('BASE'), findsOneWidget, reason: 'يجب أن تُغلق صفحتنا');
    await tester.runAsync(session.dispose);
  });

  testWidgets('«لا، أوقف» تُغلق الشاشة بلا نقل', (tester) async {
    final session = newSession();
    await tester.runAsync(() => session.open([item]));
    var transferred = 0;
    final navKey = GlobalKey<NavigatorState>();
    await openPlayer(tester, navKey, session, (_, _) async => transferred++);

    unawaited(navKey.currentState!.maybePop());
    await settle(tester);
    await tester.tap(find.byType(TextButton).last);
    await settle(tester);

    expect(transferred, 0);
    expect(find.text('BASE'), findsOneWidget);
    await tester.runAsync(session.dispose);
  });
}
