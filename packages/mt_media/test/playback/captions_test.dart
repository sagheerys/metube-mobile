import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

/// **Subtitles over the video (owner's request 2026-10-14)**: a sentence
/// that stays put, the spoken word lit along it, above the controls when
/// they show, and a CC button that hides them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Duration ms(int n) => Duration(milliseconds: n);

  MTCaptionLine line(int from, int to, String text, {bool timed = true}) {
    final words = text.split(' ');
    final step = (to - from) ~/ words.length;
    return MTCaptionLine(
      start: ms(from),
      end: ms(to),
      text: text,
      words: timed
          ? [
              for (var i = 0; i < words.length; i++)
                MTCaptionWord(ms(from + step * i), words[i]),
            ]
          : null,
    );
  }

  group('sentences', () {
    test('short automatic lines gather into one sentence', () {
      final blocks = MTCaptionBlock.group([
        line(0, 1000, 'winter is coming'),
        line(1000, 2000, 'early this year'),
        line(2000, 3000, 'so pack well'),
      ]);
      expect(
        blocks.single.text,
        'winter is coming early this year so pack well',
      );
      expect(blocks.single.words, hasLength(9));
    });

    test('a pause, a full sentence or two lines of text start another', () {
      final blocks = MTCaptionBlock.group([
        line(0, 1000, 'first thought'),
        line(4000, 5000, 'after a long pause'),
        line(5000, 6000, 'x' * 70),
      ]);
      expect(blocks.map((b) => b.text), [
        'first thought',
        'after a long pause',
        'x' * 70,
      ]);
      // Held until the next one when it follows closely, so the screen
      // does not blink empty; a moment after the words before a silence.
      expect(blocks[0].until, ms(1000) + MTCaptionBlock.linger);
      expect(blocks[1].until, ms(5000));
    });

    test('the sentence and the word at a moment', () {
      final blocks = MTCaptionBlock.group([line(1000, 4000, 'one two three')]);
      expect(MTCaptionBlock.indexAt(blocks, ms(500)), -1);
      expect(MTCaptionBlock.indexAt(blocks, ms(1000)), 0);
      expect(blocks.single.wordAt(ms(2100)), 1);
      expect(MTCaptionBlock.indexAt(blocks, ms(4800)), -1);
    });

    test('a creator\'s own track, with no word timing, shows whole', () {
      final blocks = MTCaptionBlock.group([
        line(0, 2000, 'a whole line', timed: false),
      ]);
      expect(blocks.single.words, isNull);
      expect(blocks.single.wordAt(ms(500)), -1);
    });
  });

  group('on screen', () {
    late VideoPlayerController controller;

    setUp(() async {
      VideoPlayerPlatform.instance = FakeVideoPlatform();
      controller = VideoPlayerController.networkUrl(Uri.parse('https://x/a'));
      await controller.initialize();
    });
    tearDown(() => controller.dispose());

    Widget host(
      MTCaptions captions, {
      Locale locale = const Locale('en'),
      Size size = const Size(640, 360),
      double lift = 12,
      bool clearCenter = false,
    }) => MaterialApp(
      locale: locale,
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      theme: mtTheme(MTVariant.superApp, Brightness.dark),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: MTCaptionsLayer(
              controller: controller,
              captions: captions,
              lift: lift,
              clearCenter: clearCenter,
            ),
          ),
        ),
      ),
    );

    testWidgets('the spoken word is lit, the rest a step dimmer', (
      tester,
    ) async {
      final captions = MTCaptions(
        lines: [line(1000, 4000, 'one two three')],
        shown: ValueNotifier(true),
      );
      controller.value = controller.value.copyWith(position: ms(2100));
      await tester.pumpWidget(host(captions));
      await tester.pump(const Duration(milliseconds: 300));

      final text = tester.widget<RichText>(
        find.descendant(
          of: find.byType(MTCaptionsLayer),
          matching: find.byType(RichText),
        ),
      );
      // Text.rich wraps the sentence in the style it inherits.
      final outer = text.text as TextSpan;
      final sentence = outer.children!.single as TextSpan;
      final spans = sentence.children!.cast<TextSpan>();
      final alphas = [for (final s in spans) s.style!.color!.a];
      expect(spans.map((s) => s.text!.trim()), ['one', 'two', 'three']);
      expect(alphas[1], 1.0);
      expect(alphas[0], lessThan(1.0));
      expect(alphas[2], lessThan(1.0));
    });

    testWidgets('hidden by its switch, and nothing between sentences', (
      tester,
    ) async {
      final shown = ValueNotifier(true);
      final captions = MTCaptions(
        lines: [line(1000, 2000, 'only words')],
        shown: shown,
      );
      controller.value = controller.value.copyWith(position: ms(1500));
      await tester.pumpWidget(host(captions));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('only'), findsOneWidget);

      shown.value = false;
      await tester.pumpAndSettle();
      expect(find.textContaining('only'), findsNothing);

      shown.value = true;
      controller.value = controller.value.copyWith(position: ms(9000));
      await tester.pumpAndSettle();
      expect(find.textContaining('only'), findsNothing);
    });

    // Seen on a phone: the controls lifted a two-line sentence over the
    // play button of the small player above the details.
    testWidgets('kept clear of the play button while the controls show', (
      tester,
    ) async {
      final sentence = 'a sentence long enough to need two lines here ' * 2;
      controller.value = controller.value.copyWith(position: ms(500));
      Future<Rect?> capsule(Size size, double lift) async {
        await tester.pumpWidget(
          host(
            MTCaptions(
              lines: [line(0, 3000, sentence.trim())],
              shown: ValueNotifier(true),
            ),
            size: size,
            lift: lift,
            clearCenter: true,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final text = find.textContaining('sentence');
        return text.evaluate().isEmpty ? null : tester.getRect(text);
      }

      // The phone's small player: no room under the button, so it waits.
      expect(await capsule(const Size(384, 216), 108), isNull);
      // Full screen on its side: below the button, in fewer lines.
      const wide = Size(823, 384);
      final rect = await capsule(wide, 80);
      expect(rect, isNotNull);
      expect(rect!.top, greaterThan(wide.height / 2 + 30));
      expect(rect.bottom, lessThanOrEqualTo(wide.height - 80));
    });

    // Owner's request 2026-10-14: the dark box behind the words can go,
    // and the letters then carry an edge of their own.
    testWidgets('dark, light, or no background, with an edge when none', (
      tester,
    ) async {
      controller.value = controller.value.copyWith(position: ms(1500));
      Future<(Decoration?, List<Shadow>?)> drawn(MTCaptionBackground b) async {
        await tester.pumpWidget(
          host(
            MTCaptions(
              lines: [line(1000, 2000, 'only words')],
              shown: ValueNotifier(true),
              background: b,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final box = tester.widget<Container>(
          find
              .ancestor(
                of: find.byType(RichText),
                matching: find.byType(Container),
              )
              .first,
        );
        final text = tester.widget<RichText>(
          find.descendant(
            of: find.byType(MTCaptionsLayer),
            matching: find.byType(RichText),
          ),
        );
        return (box.decoration, text.text.style?.shadows);
      }

      final (solid, solidEdge) = await drawn(MTCaptionBackground.solid);
      final (faint, _) = await drawn(MTCaptionBackground.faint);
      final (none, noneEdge) = await drawn(MTCaptionBackground.none);
      double alpha(Decoration? d) => (d! as BoxDecoration).color!.a;
      expect(alpha(faint), lessThan(alpha(solid)));
      expect(solidEdge, isNull);
      expect(none, isNull);
      expect(noneEdge, isNotEmpty);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets(
        'a long sentence fits at any text size (${locale.languageCode})',
        (tester) async {
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          controller.value = controller.value.copyWith(position: ms(500));
          for (final scale in const [1.0, 1.3, 2.0]) {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.pumpWidget(
              host(
                MTCaptions(
                  lines: [
                    line(
                      0,
                      3000,
                      'رحلة إلى جبال السروات في موسم الضباب مع عدسة الجنوب '
                      'and a few English words',
                    ),
                  ],
                  shown: ValueNotifier(true),
                  scale: 1.2,
                ),
                locale: locale,
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull, reason: 'at $scale');
          }
        },
      );
    }
  });

  group('the CC button', () {
    setUp(() {
      VideoPlayerPlatform.instance = FakeVideoPlatform();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    Future<MTVideoSession> show(
      WidgetTester tester,
      MTCaptions? Function(PlaylistItem item)? captions,
    ) async {
      tester.view.physicalSize = const Size(2400, 1200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final store = MemoryKeyValueStore();
      final mutex = PrefsMutex();
      final session = MTVideoSession(
        resolver: PlaybackSourceResolver(
          endpoint: ServerStreamEndpoint.none,
          fileExists: (_) => true,
        ),
        positions: PlaybackPositionStore(store: store, mutex: mutex),
        prefs: PlaybackPrefs(store: store, mutex: mutex),
        saveInterval: const Duration(hours: 1),
      );
      await tester.runAsync(
        () => session.open(const [
          PlaylistItem(
            canonicalUrl: 'https://x/a',
            title: 'a',
            localPath: '/media/a.mp4',
          ),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          home: MTVideoFullscreenPage(session: session, captions: captions),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return session;
    }

    Future<void> leave(WidgetTester tester, MTVideoSession session) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(session.dispose);
    }

    testWidgets('shows and hides the subtitles, and lights when on', (
      tester,
    ) async {
      final shown = ValueNotifier(false);
      final session = await show(
        tester,
        (_) => MTCaptions(lines: [line(0, 9000, 'hello')], shown: shown),
      );
      expect(find.byIcon(Icons.closed_caption_off_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.closed_caption_off_rounded));
      // The controls wait to see whether a tap is a double one (a seek).
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      expect(shown.value, isTrue);
      expect(find.byIcon(Icons.closed_caption_rounded), findsOneWidget);
      await leave(tester, session);
    });

    // Owner's request 2026-10-14: a switch between the clip's languages,
    // beside CC.
    testWidgets('the language switch walks the clip\'s languages', (
      tester,
    ) async {
      final language = ValueNotifier<String?>(null);
      final arabic = [line(0, 9000, 'مرحبا')];
      final session = await show(
        tester,
        (_) => MTCaptions(
          lines: arabic,
          tracks: {
            'ar': arabic,
            'en': [line(0, 9000, 'hello')],
          },
          language: language,
          shown: ValueNotifier(true),
        ),
      );
      expect(find.text('AR'), findsOneWidget);
      expect(find.textContaining('مرحبا'), findsOneWidget);

      await tester.tap(find.text('AR'));
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      expect(language.value, 'en');
      expect(find.text('EN'), findsOneWidget);
      expect(find.textContaining('hello'), findsOneWidget);
      expect(find.textContaining('مرحبا'), findsNothing);
      await leave(tester, session);
    });

    testWidgets('no language switch for one language, or while hidden', (
      tester,
    ) async {
      final one = await show(
        tester,
        (_) => MTCaptions(
          lines: [line(0, 9000, 'hello')],
          language: ValueNotifier(null),
          shown: ValueNotifier(true),
        ),
      );
      expect(find.text('EN'), findsNothing);
      await leave(tester, one);

      final hidden = await show(
        tester,
        (_) => MTCaptions(
          lines: [line(0, 9000, 'hello')],
          tracks: {
            'en': [line(0, 9000, 'hello')],
            'ar': [line(0, 9000, 'مرحبا')],
          },
          language: ValueNotifier(null),
          shown: ValueNotifier(false),
        ),
      );
      expect(find.text('EN'), findsNothing);
      await leave(tester, hidden);
    });

    testWidgets('a clip without subtitles has no button', (tester) async {
      final session = await show(tester, (_) => null);
      expect(find.byIcon(Icons.closed_caption_off_rounded), findsNothing);
      expect(find.byIcon(Icons.closed_caption_rounded), findsNothing);
      await leave(tester, session);
    });
  });
}
