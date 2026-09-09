import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **A field regression proven with a trace on the device (2026-09-03).**
///
/// Field report: "coming back from reels the audio keeps playing in the
/// app's background with no mini player… and it broke the app completely so
/// no other clips play".
///
/// The chain as the log captured it on the emulator: `dispose`, then
/// `dispose-1`, then **nothing** — because `onLive`, which is a `ref.read`
/// from a deactivated `ConsumerState`, threw. So the controller was never
/// disposed, `super.dispose()` never ran, **and the framework never cleared
/// `state._element`**, so `mounted` stayed true on a dead screen: the
/// pending load passed every `mounted` guard and played a clip nobody owned
/// and nothing could stop.
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
  }) => MaterialApp(
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

  /// Releasing is asynchronous by design (silence, dispose, close the
  /// platform streams).
  /// **And `runAsync` is a necessity rather than decoration:** disposing
  /// `video_player` waits for its subscription to the platform stream to be
  /// cancelled, and that does not complete inside the test's fake time.
  /// Proven with an isolated experiment before this line was written.
  Future<void> settleTeardown(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }

  /// The host callback behaving exactly as it did after the tree was
  /// deactivated.
  void throwingOnLive(Future<void> Function()? pauser) {
    throw StateError('Cannot use "ref" after the widget was disposed');
  }

  testWidgets('onLive throwing at death leaves no orphaned player running', (
    tester,
  ) async {
    await tester.pumpWidget(host([short('a')], onLive: throwingOnLive));
    await tester.pump(); // postFrameCallback ⇒ _load
    await tester.pumpAndSettle();
    expect(platform.playing, hasLength(1), reason: 'الريل يعمل قبل الرجوع');

    // Going back: the whole tree is removed, and `onLive(null)` throws on
    // the way.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    await settleTeardown(tester);

    expect(
      platform.playing,
      isEmpty,
      reason: 'صوت يعمل بلا واجهة — بلاغ المالك بالنص',
    );
    expect(platform.alive, isEmpty, reason: 'متحكم لم يُصرَّف = تسريب مرمّز');
  });

  testWidgets('going back during preparation plays nothing after death', (
    tester,
  ) async {
    platform.createDelay = const Duration(milliseconds: 80);
    await tester.pumpWidget(host([short('a')], onLive: throwingOnLive));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20)); // still preparing

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(
      const Duration(milliseconds: 200),
    ); // preparation finishes now
    await settleTeardown(tester);

    expect(
      platform.playing,
      isEmpty,
      reason: 'الحارس لا يجوز أن يعتمد على mounted',
    );
    expect(platform.alive, isEmpty);
  });

  testWidgets(
    'a healthy onLive is handed a paused player while alive, and null at death',
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
    },
  );
}
