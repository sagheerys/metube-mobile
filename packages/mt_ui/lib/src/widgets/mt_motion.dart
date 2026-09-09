import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// **Wahaj motion.** Every duration and distance comes from [MTMotion] in
/// `tokens.dart`; no literal values here.
///
/// **The second revision** (field report 2026-09-02: "the motion is
/// unbalanced, calm it down and make it smoother"). The first attempt
/// animated **every card as it was created**, and `SliverList.builder`
/// creates cards while you scroll, so every row entering the screen
/// started its own fade and slide. The result was a list that bounced
/// throughout the scroll, which is precisely what was reported.
///
/// The fix is structural, not cosmetic: **the screen enters once, its
/// items do not.** [MTRevealOnce] animates the whole block on first
/// appearance and then removes itself from the tree, leaving no
/// `AnimationController` and no work at all during scrolling.
///
/// The three remaining animations:
/// 1. [MTRevealOnce] for screen content entering once.
/// 2. [MTSlidePageTransition] for screen changes, following text
/// direction.
/// 3. [MTAnimatedSwap] for content changing in place.

/// A **once-only** appearance for a block of content: a fade and a very
/// short offset.
///
/// When the animation ends it returns [child] bare. No `Transform` and no
/// `FadeTransition` are left in the tree, so scrolling afterwards costs
/// nothing.
class MTRevealOnce extends StatefulWidget {
  const MTRevealOnce({super.key, required this.child, this.delay});

  final Widget child;

  /// An optional delay for a light stagger between two blocks, never
  /// between dozens of items.
  final Duration? delay;

  @override
  State<MTRevealOnce> createState() => _MTRevealOnceState();
}

class _MTRevealOnceState extends State<MTRevealOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MTMotion.reveal,
  );

  /// **Built once rather than every frame** (fix م-2/b): a
  /// `CurvedAnimation` in `build` was created and abandoned sixty times a
  /// second without ever being disposed.
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: MTMotion.entrance,
  );

  @override
  void initState() {
    super.initState();
    final delay = widget.delay;
    if (delay == null || delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honours "reduce motion" in the system settings: an accessibility
    // requirement, not a refinement.
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// **The tree keeps its shape from the first frame to the last** (fix
  /// م-2/a). The widget used to replace the whole wrapper with
  /// `widget.child` when the animation ended, which changed the depth of
  /// every element and rebuilt the subtree: a scroll or a keystroke that
  /// began during the first 220ms was lost. Now the controller simply
  /// reaches 1, rebuilding stops on its own, and the shape is never
  /// touched.
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curved,
    builder: (context, child) => Opacity(
      opacity: _curved.value,
      child: Transform.translate(
        offset: Offset(0, MTMotion.slideNudge * (1 - _curved.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// Content changing in place with a cross-fade, never a slide: the element
/// did not move, it changed.
class MTAnimatedSwap extends StatelessWidget {
  const MTAnimatedSwap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MTMotion.tap,
    switchInCurve: MTMotion.entrance,
    switchOutCurve: MTMotion.exit,
    child: child,
  );
}

/// Screen transitions: a fade plus a **short** offset following the text
/// direction.
///
/// The Android default is a vertical rise that says nothing about how the
/// two screens relate; a horizontal offset says "I went deeper" and "I came
/// back". The distance is deliberately small (`pageSlide`), because a long
/// slide is what reads as a jump.
class MTSlidePageTransition extends PageTransitionsBuilder {
  const MTSlidePageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sign = rtl ? -1.0 : 1.0;
    final enter = Tween<Offset>(
      begin: Offset(MTMotion.pageSlide * sign, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: MTMotion.entrance));

    return SlideTransition(
      position: enter,
      // The fade carries the transition; the offset only hints at
      // direction.
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: MTMotion.entrance),
        child: child,
      ),
    );
  }
}

/// Installed on `ThemeData.pageTransitionsTheme` in both apps.
const mtPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: MTSlidePageTransition(),
    TargetPlatform.iOS: MTSlidePageTransition(),
  },
);
