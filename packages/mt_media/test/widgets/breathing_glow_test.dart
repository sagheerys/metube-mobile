import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The glow behind the cover** (2026-09-24).
///
/// What matters is not how it looks — that is judged by eye on the phone —
/// but when it moves: only while playing, never for someone who turned
/// animations off, and never asking for frames once it has settled.
void main() {
  Widget host(ValueNotifier<bool> playing, {bool reduceMotion = false}) =>
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Center(
            child: MTBreathingGlow(
              playing: playing,
              size: 200,
              child: const SizedBox.square(dimension: 200),
            ),
          ),
        ),
      );

  group('the embers (the owner\'s pick, 2026-09-24)', () {
    test('at rest both sit at the centre: the still halo of before', () {
      final (large, small) = MTBreathingGlow.embersAt(3.7, 0);

      expect(large.centre, Offset.zero);
      expect(small.centre, Offset.zero);
    });

    test('awake, the large one goes ALL the way round the cover in one '
        'turn — the complaint was a glow that stayed in one place', () {
      var left = false, right = false, up = false, down = false;
      for (var s = 0.0; s < 9; s += 0.25) {
        final c = MTBreathingGlow.embersAt(s, 1).$1.centre;
        left |= c.dx < -0.3;
        right |= c.dx > 0.3;
        up |= c.dy < -0.2;
        down |= c.dy > 0.2;
      }

      expect([left, right, up, down], everyElement(isTrue));
    });

    test('the small one circles the OTHER way, so they meet and part', () {
      double turning(int index) {
        MTEmber at(double s) {
          final (large, small) = MTBreathingGlow.embersAt(s, 1);
          return index == 0 ? large : small;
        }

        final a = at(1).centre, b = at(1.2).centre;
        // The sign of the cross product is the direction of travel.
        return a.dx * b.dy - a.dy * b.dx;
      }

      expect(turning(0).sign, isNot(turning(1).sign));
    });
  });

  testWidgets('paused, it asks for no frames at all', (tester) async {
    final playing = ValueNotifier(false);
    await tester.pumpWidget(host(playing));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('playing, it moves; paused again, it settles and stops', (
    tester,
  ) async {
    final playing = ValueNotifier(true);
    await tester.pumpWidget(host(playing));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.hasRunningAnimations, isTrue);

    playing.value = false;
    await tester.pump();
    await tester.pump(MTBreathingGlow.settle * 2);

    // Stopped for good, not merely slowed: a paused player left on screen
    // would otherwise keep the phone drawing sixty frames a second.
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with animations turned off in Android it never moves, even '
      'while playing', (tester) async {
    final playing = ValueNotifier(true);
    await tester.pumpWidget(host(playing, reduceMotion: true));
    await tester.pump(const Duration(seconds: 3));

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('it sizes to the cover and takes no touches from it', (
    tester,
  ) async {
    final playing = ValueNotifier(true);
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.lite, Brightness.dark),
        home: Center(
          child: MTBreathingGlow(
            playing: playing,
            size: 200,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => tapped++,
              child: const SizedBox.square(dimension: 200),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(tester.getSize(find.byType(MTBreathingGlow)), const Size(200, 200));
    await tester.tapAt(tester.getCenter(find.byType(MTBreathingGlow)));
    expect(tapped, 1);
    playing.value = false;
    await tester.pump(MTBreathingGlow.settle * 2);
  });
}
