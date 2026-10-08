import 'dart:async';

import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'mt_polish.dart';

/// **The server card's state icon, alive while it means "trying".**
///
/// A still glyph cannot tell a check of one second from one of thirty, so
/// "checking the connection" looked stuck (field request 2026-10-04).
/// While [checking], the arrows inside the cloud turn, the sign every
/// phone uses for "working on it". Any other state is a still [icon], and
/// a change of state crossfades into it rather than snapping. When the
/// system asks to reduce motion the arrows stand still.
class MTConnectionIcon extends StatefulWidget {
  const MTConnectionIcon({
    super.key,
    required this.icon,
    required this.color,
    this.checking = false,
    this.size = 26,
  });

  /// The still glyph for a settled state; ignored while [checking].
  final IconData icon;
  final Color color;
  final bool checking;
  final double size;

  /// One turn of the arrows. Slow on purpose: a wait, not an alarm.
  static const Duration turn = Duration(milliseconds: 1400);

  /// **The least time the arrows turn once started** (owner's choice
  /// 2026-10-08). A server on the home network answers in a tenth of a
  /// second, so a refresh changed nothing the eye could see and looked
  /// ignored. Long enough to be seen, short enough not to delay the answer
  /// beside it, which shows at once.
  static const Duration shortestTurn = Duration(milliseconds: 600);

  @override
  State<MTConnectionIcon> createState() => _MTConnectionIconState();
}

class _MTConnectionIconState extends State<MTConnectionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: MTConnectionIcon.turn,
  );

  /// Whether the arrows show: from the start of a check until it ends and
  /// [MTConnectionIcon.shortestTurn] has passed.
  bool _turning = false;
  Timer? _hold;

  void _sync() {
    final still = MediaQuery.disableAnimationsOf(context);
    if (widget.checking) {
      _hold?.cancel();
      _hold = null;
      _turning = true;
    } else if (_turning) {
      // Measured on the arrows' own clock, which only runs while they turn.
      final turned = _spin.lastElapsedDuration ?? Duration.zero;
      final left = still
          ? Duration.zero
          : MTConnectionIcon.shortestTurn - turned;
      if (left <= Duration.zero) {
        _turning = false;
      } else {
        _hold ??= Timer(left, _settle);
      }
    }
    _drive(still: still);
  }

  void _settle() {
    _hold = null;
    if (!mounted) return;
    setState(() => _turning = false);
    _drive(still: MediaQuery.disableAnimationsOf(context));
  }

  void _drive({required bool still}) {
    if (_turning && !still) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MTConnectionIcon old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final Widget glyph = _turning
        ? SizedBox.square(
            key: const ValueKey('mt-connection-checking'),
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.cloud_outlined, size: size, color: widget.color),
                // Inside the cloud's body, which sits a little low in the
                // glyph.
                Padding(
                  padding: EdgeInsets.only(top: size * 0.12),
                  child: RotationTransition(
                    turns: _spin,
                    child: Icon(
                      Icons.sync_rounded,
                      size: size * 0.42,
                      color: widget.color,
                    ),
                  ),
                ),
              ],
            ),
          )
        : Icon(
            widget.icon,
            key: ValueKey(widget.icon),
            size: size,
            color: widget.color,
          );
    return AnimatedSwitcher(
      duration: mtMotionDuration(context, MTMotion.reveal),
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
      child: glyph,
    );
  }
}
