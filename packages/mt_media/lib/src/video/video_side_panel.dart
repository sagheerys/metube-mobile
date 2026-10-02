import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// What the app shows beside the video in full screen, for the item now
/// playing: a feature this package does not know, such as a transcript.
class MTVideoPanel {
  const MTVideoPanel({
    required this.icon,
    required this.label,
    required this.builder,
  });

  final IconData icon;
  final String label;

  /// The panel's content; [close] puts it away.
  final Widget Function(BuildContext context, VoidCallback close) builder;
}

/// A panel sliding in from the end edge. Unlike the queue it leaves the
/// video undimmed and playing beside it: what it holds is read along with
/// the picture, not instead of it.
class MTVideoEndPanel extends StatelessWidget {
  const MTVideoEndPanel({super.key, required this.child});

  final Widget child;

  static const _widest = 420.0;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final width = math.min(_widest, MediaQuery.sizeOf(context).width * 0.45);
    return PositionedDirectional(
      end: 0,
      top: 0,
      bottom: 0,
      width: width,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: width, end: 0),
        duration: MTMotion.medium,
        curve: MTMotion.ease,
        builder: (context, offset, child) => Transform.translate(
          offset: Offset(
            Directionality.of(context) == TextDirection.rtl ? -offset : offset,
            0,
          ),
          child: child,
        ),
        child: Material(
          color: p.bg,
          child: SafeArea(child: child),
        ),
      ),
    );
  }
}
