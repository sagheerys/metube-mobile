import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// **A vertical drag closes the screen**: the content follows the finger
/// downwards, never upwards, and on release it either closes, if the
/// distance passes [MTMotion.dismissDragDistance] or the velocity passes
/// [MTMotion.dismissFlingVelocity], or returns calmly to place.
///
/// **It competes with nothing**: the progress bar drags horizontally and
/// the buttons are tapped, and only `onVerticalDragUpdate` is used here.
/// When the system asks to reduce motion, dismissal works without the
/// visual tracking.
class MTDragToDismiss extends StatefulWidget {
  const MTDragToDismiss({super.key, required this.child});

  final Widget child;

  @override
  State<MTDragToDismiss> createState() => _MTDragToDismissState();
}

class _MTDragToDismissState extends State<MTDragToDismiss>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: MTMotion.tap,
  )..addListener(() => setState(() => _offset = _settle.value * _from));

  double _offset = 0;
  double _from = 0;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_settle.isAnimating) _settle.stop();
    setState(() => _offset = (_offset + d.delta.dy).clamp(0, double.infinity));
  }

  void _onEnd(DragEndDetails d) {
    final velocity = d.velocity.pixelsPerSecond.dy;
    if (_offset > MTMotion.dismissDragDistance ||
        velocity > MTMotion.dismissFlingVelocity) {
      Navigator.of(context).maybePop();
      return;
    }
    // A calm return to place, with no bounce.
    _from = _offset;
    _settle
      ..value = 1
      ..animateTo(0, curve: MTMotion.entrance);
  }

  @override
  Widget build(BuildContext context) {
    final follow = !MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: _onUpdate,
      onVerticalDragEnd: _onEnd,
      child: Transform.translate(
        offset: Offset(0, follow ? _offset : 0),
        child: widget.child,
      ),
    );
  }
}
