import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// The "now playing" indicator: four swaying bars in the accent colour,
/// from the Wahaj reference.
class MTEqualizer extends StatefulWidget {
  const MTEqualizer({super.key, this.size = 14, this.animate = true});

  final double size;
  final bool animate;

  @override
  State<MTEqualizer> createState() => _MTEqualizerState();
}

class _MTEqualizerState extends State<MTEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  static const _heights = [6.0, 13.0, 9.0, 12.0];
  static const _delays = [0.0, 0.2, 0.4, 0.1];

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat(reverse: true);
  }

  /// **It actually stops when playback pauses** (field report 2026-09-04:
  /// the effect kept running after the clip stopped, suggesting it was
  /// still playing). The flag was only read in `initState`, so changing it
  /// later did not stop the controller, which went on rebuilding sixty
  /// times a second over a silent clip.
  @override
  void didUpdateWidget(MTEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = MTThemeX.of(context).palette.accent;
    final scale = widget.size / 14;
    return SizedBox(
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) SizedBox(width: 2.5 * scale),
              _bar(i, accent, scale),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(int i, Color accent, double scale) {
    final t = widget.animate
        ? MTMotion.ease.transform(((_controller.value + _delays[i]) % 1.0))
        : 1.0;
    final factor = 0.45 + 0.55 * t;
    return Container(
      width: 3 * scale,
      height: _heights[i] * scale * factor,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(2 * scale),
      ),
    );
  }
}
