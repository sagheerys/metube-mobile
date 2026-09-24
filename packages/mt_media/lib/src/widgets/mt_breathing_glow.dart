import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The glow behind the cover breathes while the sound plays** (asked
/// 2026-09-24, after the owner saw Samsung Music's drifting background).
///
/// Samsung tints its background from the cover; the owner declined that,
/// because a clip's colours would repaint the app. So the idea is kept and
/// the source changed: the identity is called "glow", and this is a halo in
/// the app's **own accent** — ember in Super, petrol in Lite, read from the
/// palette like everything else — widening and fading slowly behind the
/// tilted cover, and drifting a little on a period of its own so the motion
/// never reads as a loop.
///
/// **It says something.** Moving means playing; paused, it settles within a
/// second and stays still. And it stays still for anyone who turned
/// animations off in Android: the halo is then shown at rest, not removed.
class MTBreathingGlow extends StatefulWidget {
  const MTBreathingGlow({
    super.key,
    required this.playing,
    required this.size,
    required this.child,
  });

  final ValueListenable<bool> playing;

  /// The cover's side; the halo is sized from it.
  final double size;
  final Widget child;

  /// One breath. Slow on purpose: at the pace of calm breathing the eye
  /// registers life without being drawn away from the controls.
  static const breath = Duration(seconds: 7);

  /// Settling to rest after a pause, and waking after a play.
  static const settle = Duration(milliseconds: 900);

  @override
  State<MTBreathingGlow> createState() => _MTBreathingGlowState();
}

class _MTBreathingGlowState extends State<MTBreathingGlow>
    with TickerProviderStateMixin {
  // Periods of 7, 11 and 13 seconds, and a clock of their product, so the
  // wrap from the end back to zero lands every wave where it started.
  static const _driftX = 11.0;
  static const _driftY = 13.0;
  static const _cycleSeconds = 7 * 11 * 13;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _cycleSeconds),
  );

  late final AnimationController _amp =
      AnimationController(vsync: this, duration: MTBreathingGlow.settle)
        ..addStatusListener((status) {
          // Nothing moves at rest, so nothing needs a frame.
          if (status == AnimationStatus.dismissed) _clock.stop();
        });

  bool _still = false;

  @override
  void initState() {
    super.initState();
    widget.playing.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(MTBreathingGlow old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) {
      old.playing.removeListener(_sync);
      widget.playing.addListener(_sync);
      _sync();
    }
  }

  void _sync() {
    if (_still) {
      _amp.value = 0;
      _clock.stop();
      return;
    }
    if (widget.playing.value) {
      if (!_clock.isAnimating) _clock.repeat();
      _amp.forward();
    } else {
      _amp.reverse();
    }
  }

  @override
  void dispose() {
    widget.playing.removeListener(_sync);
    _clock.dispose();
    _amp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = MTThemeX.of(context).palette.accent;
    // Night needs more of it to be seen on espresso than day needs on
    // cream, where the same strength would read as a stain.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rest = dark ? 0.30 : 0.22;
    final swing = dark ? 0.16 : 0.14;
    final reach = widget.size * 0.34;
    // The cover hides the middle of the halo, so its strength is kept out
    // to just past the cover's edge (0.55 of a radius of 0.84 sides) and
    // only fades beyond it; a halo fading from the centre shows nothing.

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -reach,
          top: -reach,
          right: -reach,
          bottom: -reach,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_clock, _amp]),
                builder: (context, _) {
                  final t = _clock.value * _cycleSeconds;
                  final a = _amp.value;
                  final breath =
                      (1 - math.cos(2 * math.pi * t / _breathSeconds)) / 2;
                  final dx = math.sin(2 * math.pi * t / _driftX) * a;
                  final dy = math.sin(2 * math.pi * t / _driftY) * a;
                  return Transform.translate(
                    offset: Offset(
                      dx * widget.size * 0.06,
                      dy * widget.size * 0.04,
                    ),
                    child: Transform.scale(
                      scale: 1 + 0.08 * breath * a,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(
                                alpha: rest + swing * breath * a,
                              ),
                              accent.withValues(alpha: 0),
                            ],
                            stops: const [0.55, 1],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }

  static final _breathSeconds = MTBreathingGlow.breath.inSeconds.toDouble();
}
