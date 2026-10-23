import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_polish.dart';

/// A small round arrow over a long list that takes the reader to its end in
/// one tap, for a list whose newest entry is at the bottom (a log).
///
/// It comes out while the reader scrolls toward the end and is still more
/// than a screen away from it, and goes away on a scroll back or once the
/// end is near, so it never rests over the lines being read. The list
/// leaves [reserve] under its last item, so the arrow never covers that
/// either.
class MTJumpToEnd extends StatefulWidget {
  const MTJumpToEnd({
    super.key,
    required this.controller,
    required this.tooltip,
    required this.child,
    this.fresh = false,
    this.onReachedEnd,
  });

  /// The controller of the scrollable in [child].
  final ScrollController controller;
  final String tooltip;
  final Widget child;

  /// New entries arrived below the part on screen: the arrow carries a
  /// dot. It does not bring the arrow out by itself, because a busy log
  /// gains a line every few seconds and the arrow would never stay away.
  final bool fresh;

  /// Called when the reader gets near the end, by the arrow or by hand.
  final VoidCallback? onReachedEnd;

  /// How close to the end counts as "at the end", in logical pixels.
  static const double nearEnd = 48;

  /// Puts [controller] at the true end of its list. A list of entries of
  /// uneven height only estimates its length until the entries near the
  /// end are laid out, so one jump lands short; each jump lays out more
  /// of them, and a few settle it. The estimate can also shrink under the
  /// jump and leave the list past its end, showing nothing, so the test is
  /// "exactly at the end", not "nothing below".
  static Future<void> settleAtEnd(ScrollController controller) async {
    for (var i = 0; i < 12 && controller.hasClients; i++) {
      final p = controller.position;
      if ((p.pixels - p.maxScrollExtent).abs() < 0.5) return;
      controller.jumpTo(p.maxScrollExtent);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  /// The space a list leaves under its last item for the arrow.
  static const double reserve = _size + MTSpace.lg * 2;

  static const double _size = 40;

  @override
  State<MTJumpToEnd> createState() => _MTJumpToEndState();
}

class _MTJumpToEndState extends State<MTJumpToEnd> {
  bool _out = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(MTJumpToEnd old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  bool get _nearEnd {
    final c = widget.controller;
    return !c.hasClients || c.position.extentAfter < MTJumpToEnd.nearEnd;
  }

  bool get _farFromEnd {
    final c = widget.controller;
    return c.hasClients &&
        c.position.extentAfter > c.position.viewportDimension;
  }

  void _show(bool out) {
    if (_out != out) setState(() => _out = out);
  }

  void _onScroll() {
    if (!_nearEnd) return;
    _show(false);
    widget.onReachedEnd?.call();
  }

  bool _onUserScroll(UserScrollNotification n) {
    // Flutter names the direction after the content: `reverse` is the
    // offset growing, which is the reader moving toward the end.
    switch (n.direction) {
      case ScrollDirection.reverse:
        if (_farFromEnd) _show(true);
      case ScrollDirection.forward:
        _show(false);
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  Future<void> _jump() async {
    _show(false);
    final c = widget.controller;
    if (!c.hasClients) return;
    if (!MediaQuery.of(context).disableAnimations) {
      await c.animateTo(
        c.position.maxScrollExtent,
        duration: MTMotion.medium,
        curve: MTMotion.ease,
      );
    }
    await MTJumpToEnd.settleAtEnd(c);
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final duration = mtMotionDuration(context, MTMotion.fast);
    return NotificationListener<UserScrollNotification>(
      onNotification: _onUserScroll,
      child: Stack(
        children: [
          widget.child,
          PositionedDirectional(
            end: MTSpace.lg,
            bottom: MTSpace.lg + MediaQuery.paddingOf(context).bottom,
            child: IgnorePointer(
              ignoring: !_out,
              child: ExcludeSemantics(
                excluding: !_out,
                child: AnimatedScale(
                  scale: _out ? 1 : 0.6,
                  duration: duration,
                  curve: MTMotion.entrance,
                  child: AnimatedOpacity(
                    opacity: _out ? 1 : 0,
                    duration: duration,
                    child: _Arrow(
                      size: MTJumpToEnd._size,
                      tooltip: widget.tooltip,
                      fresh: widget.fresh,
                      palette: p,
                      onTap: _jump,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.size,
    required this.tooltip,
    required this.fresh,
    required this.palette,
    required this.onTap,
  });

  final double size;
  final String tooltip;
  final bool fresh;
  final MTPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: MTShadow.card,
        ),
        child: Material(
          color: p.card,
          shape: CircleBorder(side: BorderSide(color: p.line2)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.arrow_downward_rounded, size: 20, color: p.ink2),
                  if (fresh)
                    PositionedDirectional(
                      top: MTSpace.xs,
                      end: MTSpace.xs,
                      child: Container(
                        width: MTSpace.xs,
                        height: MTSpace.xs,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
