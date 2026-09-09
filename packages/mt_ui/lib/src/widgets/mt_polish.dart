import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// **Light Wahaj touches** (requested 2026-09-04: "motion on some icons,
/// light touches, pretty and consistent and suited to both apps").
///
/// Three small components used by both apps. All of them take their
/// durations from [MTMotion], none of them bounces (log §4: `elasticOut`
/// and `bounceOut` are forbidden), and all of them switch themselves off
/// when the system asks to reduce motion.

/// The effective duration: zero when the system asks to reduce motion.
Duration mtMotionDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

/// **A light shrink while pressed**, which says "this is a button" before
/// it does anything.
///
/// It wraps `InkWell` rather than replacing it: the ripple stays and the
/// shrink is added. It listens at the pointer level rather than through a
/// `GestureDetector`, so it never competes for the tap.
class MTPressable extends StatefulWidget {
  const MTPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = MTMotion.pressScale,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<MTPressable> createState() => _MTPressableState();
}

class _MTPressableState extends State<MTPressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down || !widget.enabled) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.deferToChild,
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: mtMotionDuration(context, MTMotion.tap),
      // Decisive on the way down, calm on the way back up.
      curve: _down ? MTMotion.exit : MTMotion.entrance,
      child: widget.child,
    ),
  );
}

/// **Swapping an icon in place**: the old one fades while shrinking and
/// the new one grows from [MTMotion.iconSwapScale] to full size. No jump
/// between play and pause, or between an empty and a filled heart.
///
/// The icon itself is the key, so nothing animates unless it changes.
class MTIconSwap extends StatelessWidget {
  const MTIconSwap({
    super.key,
    required this.icon,
    this.size,
    this.color,
    this.semanticLabel,
    this.shadows,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: mtMotionDuration(context, MTMotion.tap),
    switchInCurve: MTMotion.entrance,
    switchOutCurve: MTMotion.exit,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(
          begin: MTMotion.iconSwapScale,
          end: 1,
        ).animate(animation),
        child: child,
      ),
    ),
    child: Icon(
      icon,
      key: ValueKey(icon.codePoint),
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      shadows: shadows,
    ),
  );
}

/// **A "rising sheet" transition**: the screen rises whole from the bottom
/// while the one beneath it dims slightly. For screens that expand out of
/// a bottom element, such as the mini player opening the audio screen.
/// Going back reverses it, so it looks like it returned where it came
/// from.
///
/// Used with `CustomTransitionPage` in the route table. It does not
/// replace the horizontal screen transition used everywhere else.
Widget mtSheetPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  final rise = CurvedAnimation(
    parent: animation,
    curve: MTMotion.entrance,
    reverseCurve: MTMotion.exit,
  );
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(rise),
    child: child,
  );
}
