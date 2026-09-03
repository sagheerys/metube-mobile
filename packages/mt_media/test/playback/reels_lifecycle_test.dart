import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **انحدار ميداني مُثبت بأثر على الجهاز (2026-09-03).**
///
/// بلاغ المالك: «عند الرجوع من الريلز يبقى الصوت يعمل في خلفية التطبيق
/// بلا مشغل مصغر… ولخبطت التطبيق تماماً فلا تعمل المقاطع الأخرى».
///
/// السلسلة كما التقطها السجل على المحاكي:
/// `dispose` ⇒ `dispose-1` ⇒ **لا شيء بعدها** — لأن `onLive` (وهو
/// `ref.read` من `ConsumerState` مُبطل) رمى. فلم يُصرَّف المتحكم، ولم
/// يُنفَّذ `super.dispose()`، **ولم يصفّر الإطارُ `state._element`**
/// فبقي `mounted == true` على شاشة ميتة: مرّ التحميل المعلّق من كل
/// حُرّاس `mounted` وشغّل مقطعاً لا يملكه أحد ولا يوقفه شيء.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlatform platform;

  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  PlaylistItem short(String id) => PlaylistItem(
        canonicalUrl: 'https://x/$id',
        title: id,
        localPath: '/media/$id.mp4',
        duration: const Duration(seconds: 30),
        aspectRatio: 0.5625,
      );

  Widget host(
    List<PlaylistItem> items, {
    void Function(Future<void> Function()? pauser)? onLive,
  }) =>
      MaterialApp(
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: MTReelsPlayer(
          lane: ShortsLane.from(items),
          resolver: PlaybackSourceResolver(
            endpoint: ServerStreamEndpoint.none,
            fileExists: (_) => true,
          ),
          onLive: onLive,
        ),
      );

  /// التحرير غير متزامن عمداً (إسكات ⇒ تصريف ⇒ إغلاق مجاري المنصة).
  /// **و`runAsync` ضرورة لا زينة:** تصريف `video_player` ينتظر إلغاء
  /// اشتراكه ببثّ المنصة، وهذا لا يكتمل داخل زمن الاختبار المزيّف —
  /// أُثبت بتجربة معزولة قبل كتابة هذا السطر.
  Future<void> settleTeardown(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
  }

  /// رد نداء المضيف كما كان يتصرف فعلاً بعد إبطال الشجرة.
  void throwingOnLive(Future<void> Function()? pauser) {
    throw StateError('Cannot use "ref" after the widget was disposed');
  }

  testWidgets('رمية onLive عند الموت لا تترك مشغلاً يتيماً يعمل',
      (tester) async {
    await tester.pumpWidget(host([short('a')], onLive: throwingOnLive));
    await tester.pump(); // postFrameCallback ⇒ _load
    await tester.pumpAndSettle();
    expect(platform.playing, hasLength(1), reason: 'الريل يعمل قبل الرجوع');

    // الرجوع: تُنزع الشجرة كلها — و`onLive(null)` يرمي في طريقه.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    await settleTeardown(tester);

    expect(platform.playing, isEmpty,
        reason: 'صوت يعمل بلا واجهة — بلاغ المالك بالنص');
    expect(platform.alive, isEmpty, reason: 'متحكم لم يُصرَّف = تسريب مرمّز');
  });

  testWidgets('رجوعٌ أثناء التحضير لا يشغّل شيئاً بعد الموت', (tester) async {
    platform.createDelay = const Duration(milliseconds: 80);
    await tester.pumpWidget(host([short('a')], onLive: throwingOnLive));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20)); // ما زال يحضّر

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 200)); // ينتهي التحضير الآن
    await settleTeardown(tester);

    expect(platform.playing, isEmpty,
        reason: 'الحارس لا يجوز أن يعتمد على mounted');
    expect(platform.alive, isEmpty);
  });

  testWidgets('onLive السليم يُسلَّم موقفاً عند الحياة وnull عند الموت',
      (tester) async {
    final handovers = <bool>[];
    await tester.pumpWidget(
      host([short('a')], onLive: (pauser) => handovers.add(pauser != null)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    await settleTeardown(tester);

    expect(handovers, [true, false]);
    expect(platform.alive, isEmpty);
  });
}
