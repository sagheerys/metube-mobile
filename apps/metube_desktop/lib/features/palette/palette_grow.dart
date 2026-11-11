import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// The palette's widest, and how far below the top of the window it opens
/// when there is no search box to open from.
const double paletteWidth = 640;
const double _topGap = 64;

/// Where the search box in the title bar stands, in the coordinates the
/// palette is laid out in; null while it is not drawn (a narrow window
/// shows a search button instead).
Rect? paletteAnchor(GlobalKey box, BuildContext context) {
  final drawn = box.currentContext?.findRenderObject();
  final overlay = Navigator.of(
    context,
    rootNavigator: true,
  ).overlay?.context.findRenderObject();
  if (drawn is! RenderBox || !drawn.attached || !drawn.hasSize) return null;
  final origin = drawn.localToGlobal(
    Offset.zero,
    ancestor: overlay is RenderBox ? overlay : null,
  );
  return origin & drawn.size;
}

/// The palette opened out of [box]: its text field where the box was, its
/// start edge a margin before the box's, and as wide as [paletteWidth]
/// allows without leaving the window.
///
/// **Out of the box, not in the middle of the window** (owner's request
/// 2026-11-11): a palette appearing somewhere else read as a separate
/// thing from the box that was clicked.
Rect paletteFrame({
  required Rect box,
  required Size window,
  required TextDirection direction,
}) {
  final width = math.min(paletteWidth, window.width - 2 * MTSpace.lg);
  final start = direction == TextDirection.rtl
      ? box.right + MTSpace.md - width
      : box.left - MTSpace.md;
  final left = start.clamp(MTSpace.lg, window.width - MTSpace.lg - width);
  final top = math.max(0.0, box.top - MTSpace.md);
  return Rect.fromLTWH(left, top, width, window.height - top - MTSpace.lg);
}

/// The room above the palette's text field: its margin, or less when the
/// box sits near the top of the window, so the field lands on the box
/// instead of a step below it.
class PaletteFieldTop extends InheritedWidget {
  const PaletteFieldTop({super.key, required this.top, required super.child});

  final double top;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaletteFieldTop>()?.top ??
      MTSpace.md;

  @override
  bool updateShouldNotify(PaletteFieldTop old) => old.top != top;
}

/// How the palette comes in: out of the search box at [from], or faded in
/// at the top of the window when the box is not shown.
Widget paletteTransition(
  BuildContext context,
  Animation<double> animation,
  Rect? from,
  Widget palette,
) {
  if (from == null) {
    return FadeTransition(
      opacity: animation,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MTSpace.lg,
            _topGap,
            MTSpace.lg,
            MTSpace.lg,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: paletteWidth),
            child: palette,
          ),
        ),
      ),
    );
  }
  final frame = paletteFrame(
    box: from,
    window: MediaQuery.sizeOf(context),
    direction: Directionality.of(context),
  );
  return Stack(
    children: [
      Positioned(
        left: frame.left,
        top: frame.top,
        width: frame.width,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: frame.height),
          child: _Grow(
            animation: animation,
            from: from.shift(-frame.topLeft),
            child: PaletteFieldTop(top: from.top - frame.top, child: palette),
          ),
        ),
      ),
    ],
  );
}

/// Opens the palette from the box's own rectangle out to its full size,
/// and closes it back into the box.
class _Grow extends StatefulWidget {
  const _Grow({
    required this.animation,
    required this.from,
    required this.child,
  });

  final Animation<double> animation;

  /// The box, in the palette's own coordinates.
  final Rect from;
  final Widget child;

  @override
  State<_Grow> createState() => _GrowState();
}

class _GrowState extends State<_Grow> {
  late final _open = CurvedAnimation(
    parent: widget.animation,
    curve: MTMotion.entrance,
    reverseCurve: MTMotion.exit,
  );

  // The words come in once the card has room for them, rather than
  // squeezed into the box's size.
  late final _words = CurvedAnimation(
    parent: widget.animation,
    curve: const Interval(0.3, 1, curve: MTMotion.ease),
  );

  @override
  void dispose() {
    _open.dispose();
    _words.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final corners = MTCorners.desktop;
    return AnimatedBuilder(
      animation: _open,
      builder: (context, child) => ClipRRect(
        clipper: _Opening(
          from: widget.from,
          t: _open.value,
          radius: ui.lerpDouble(corners.field, corners.card, _open.value)!,
        ),
        child: child,
      ),
      // The card's ground is there from the first frame, where the box
      // was, so nothing blinks out between the box and the palette.
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: MTThemeX.of(context).palette.card),
          ),
          FadeTransition(opacity: _words, child: widget.child),
        ],
      ),
    );
  }
}

class _Opening extends CustomClipper<RRect> {
  const _Opening({required this.from, required this.t, required this.radius});

  final Rect from;
  final double t;
  final double radius;

  @override
  RRect getClip(Size size) => RRect.fromRectAndRadius(
    Rect.lerp(from, Offset.zero & size, t)!,
    Radius.circular(radius),
  );

  @override
  bool shouldReclip(_Opening old) =>
      old.t != t || old.from != from || old.radius != radius;
}
