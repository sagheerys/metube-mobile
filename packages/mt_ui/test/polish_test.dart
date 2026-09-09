import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Polish guards** (requested 2026-09-04). Motion is glimpsed, not
/// watched: durations come from `MTMotion`, and none of it runs when the
/// system asks to reduce motion.
void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: MaterialApp(
      theme: mtTheme(MTVariant.lite, Brightness.light),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('MTIconSwap', () {
    testWidgets(
      'an icon change passes through a transition and settles on the new one',
      (tester) async {
        var icon = Icons.play_arrow_rounded;
        late StateSetter set;
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) {
                set = setState;
                return MTIconSwap(icon: icon);
              },
            ),
          ),
        );
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

        set(() => icon = Icons.pause_rounded);
        await tester.pump();
        await tester.pump(MTMotion.tap ~/ 2);
        // Halfway through, both are present: that is what a cross-fade is.
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'with reduced motion the switch is immediate, with no transition',
      (tester) async {
        var icon = Icons.play_arrow_rounded;
        late StateSetter set;
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) {
                set = setState;
                return MTIconSwap(icon: icon);
              },
            ),
            reduceMotion: true,
          ),
        );
        set(() => icon = Icons.pause_rounded);
        await tester.pump();
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      },
    );
  });

  group('MTPressable', () {
    testWidgets(
      'it shrinks to pressScale while pressed and returns on release',
      (tester) async {
        await tester.pumpWidget(
          host(
            const MTPressable(
              child: SizedBox(width: 100, height: 40, child: Text('زر')),
            ),
          ),
        );
        AnimatedScale scaleOf() =>
            tester.widget<AnimatedScale>(find.byType(AnimatedScale));
        expect(scaleOf().scale, 1);

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('زر')),
        );
        await tester.pump();
        expect(scaleOf().scale, MTMotion.pressScale);
        expect(
          scaleOf().scale,
          greaterThan(0.9),
          reason: 'انكماش يُلمَح لا يُشاهَد',
        );

        await gesture.up();
        await tester.pump();
        expect(scaleOf().scale, 1);
      },
    );
  });

  test('the polish durations stay under the agreed 320ms ceiling', () {
    expect(MTMotion.sheetPage.inMilliseconds, lessThanOrEqualTo(320));
    expect(MTMotion.tap.inMilliseconds, lessThanOrEqualTo(320));
    expect(MTMotion.reveal.inMilliseconds, lessThanOrEqualTo(320));
  });

  group('MTHiddenUnderRoutes', () {
    testWidgets(
      'a pure fade: no size changes, and no difference between the two directions',
      (tester) async {
        addTearDown(() => MTRouteDepth.depth.value = 0);
        MTRouteDepth.depth.value = 0;
        await tester.pumpWidget(
          host(
            const MTHiddenUnderRoutes(
              child: SizedBox(
                width: 100,
                height: 40,
                child: Text('أضف رابطاً'),
              ),
            ),
          ),
        );

        Finder inside(Type type) => find.descendant(
          of: find.byType(MTHiddenUnderRoutes),
          matching: find.byType(type),
        );
        AnimatedOpacity fade() =>
            tester.widget<AnimatedOpacity>(inside(AnimatedOpacity));
        expect(fade().opacity, 1);
        final showCurve = fade().curve;

        // **The guard**: no `AnimatedScale` anywhere on this path. The size
        // jump is what was described as "strange and uncomfortable"
        // (2026-09-05).
        expect(inside(AnimatedScale), findsNothing);

        MTRouteDepth.depth.value = 1;
        await tester.pump();
        expect(fade().opacity, 0);
        expect(fade().curve, showCurve, reason: 'منحنى واحد في الاتجاهين');

        // And it does not swallow taps while hidden.
        expect(
          tester.widget<IgnorePointer>(inside(IgnorePointer)).ignoring,
          isTrue,
        );
      },
    );

    testWidgets('visible false hides it without taking it out of the tree', (
      tester,
    ) async {
      addTearDown(() => MTRouteDepth.depth.value = 0);
      MTRouteDepth.depth.value = 0;
      await tester.pumpWidget(
        host(
          const MTHiddenUnderRoutes(
            visible: false,
            child: SizedBox(width: 100, height: 40, child: Text('أضف رابطاً')),
          ),
        ),
      );

      // **The guard**: removing it from the `Scaffold` slot by passing
      // `null` wakes the default animator, which rotates on appearance, and
      // that rotation is what was reported.
      expect(find.text('أضف رابطاً', skipOffstage: false), findsOneWidget);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.descendant(
                of: find.byType(MTHiddenUnderRoutes),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        0,
      );
    });
  });
}
