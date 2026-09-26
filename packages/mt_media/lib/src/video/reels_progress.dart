import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import '../widgets/media_time.dart';

/// The reels progress bar, **draggable** (field report 2026-09-02: "you
/// cannot seek forward or back, or grab the counter").
///
/// While dragging we show the finger's position rather than the player's,
/// or the marker jumped back with every player update and the bar seemed
/// to "resist" the finger.
///
/// **The touch area is 48 points plus [padding]** around a 3-point line. It
/// was 24 points, and everything around it belongs to tap-to-pause, so a
/// finger that slightly missed the strip paused the clip a moment later and
/// the bar took the blame (field report 2026-09-13: "seeking pauses the
/// video"). The padding sits inside the detector for the same reason: the
/// side margins and the system inset around the line scrub too.
class ReelsProgressBar extends StatefulWidget {
  const ReelsProgressBar({
    super.key,
    this.controller,
    this.onScrubStart,
    this.onScrubEnd,
    this.padding = EdgeInsets.zero,
  });

  final VideoPlayerController? controller;

  /// **The bar never plays or pauses by itself:** only the
  /// state owner knows about audio focus and the wake lock. [onScrubEnd] is
  /// called at the end of a drag **and on its cancellation**, so the clip
  /// is never left paused with no indicator.
  final VoidCallback? onScrubStart;
  final VoidCallback? onScrubEnd;

  /// Space around the track that still belongs to the bar's touch area.
  /// Keep left and right equal: the fraction is measured from the left.
  final EdgeInsets padding;

  @override
  State<ReelsProgressBar> createState() => _ReelsProgressBarState();
}

class _ReelsProgressBarState extends State<ReelsProgressBar> {
  double? _dragFraction;

  Duration _durationOf(VideoPlayerController c) => c.value.duration;

  void _seekToFraction(double fraction) {
    final controller = widget.controller;
    if (controller == null) return;
    final total = _durationOf(controller);
    if (total <= Duration.zero) return;
    controller.seekTo(total * fraction.clamp(0, 1));
  }

  /// The fraction from a horizontal coordinate: the left edge is 0 in
  /// every language, because media time runs left to right (see
  /// MTProgressSlider).
  double _fractionFrom(Offset local, double width) {
    if (width <= 0) return 0;
    return (local.dx / width).clamp(0.0, 1.0);
  }

  /// Changing page mid-drag used to leave [_dragFraction] stuck, freezing
  /// the next clip's bar at an old fraction.
  @override
  void didUpdateWidget(ReelsProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller && _dragFraction != null) {
      setState(() => _dragFraction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) {
      return Padding(
        padding: widget.padding,
        child: const SizedBox(height: kMinInteractiveDimension),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - widget.padding.horizontal;
        double fractionAt(Offset local) => _fractionFrom(
          Offset(local.dx - widget.padding.left, local.dy),
          width,
        );
        void update(Offset local) =>
            setState(() => _dragFraction = fractionAt(local));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            update(d.localPosition);
            widget.onScrubStart?.call();
          },
          onHorizontalDragUpdate: (d) => update(d.localPosition),
          onHorizontalDragEnd: (_) {
            final fraction = _dragFraction;
            if (fraction != null) _seekToFraction(fraction);
            setState(() => _dragFraction = null);
            widget.onScrubEnd?.call();
          },
          onHorizontalDragCancel: () {
            setState(() => _dragFraction = null);
            widget.onScrubEnd?.call();
          },
          // A tap on the bar is a direct jump, with no drag.
          onTapDown: (d) => _seekToFraction(fractionAt(d.localPosition)),
          child: Padding(
            padding: widget.padding,
            child: SizedBox(
              height: kMinInteractiveDimension,
              child: Center(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, state, _) {
                    final total = state.duration.inMilliseconds;
                    final playedFraction = total <= 0
                        ? 0.0
                        : (state.position.inMilliseconds / total).clamp(
                            0.0,
                            1.0,
                          );
                    final dragging = _dragFraction != null;
                    final shown = _dragFraction ?? playedFraction;
                    // **The whole row, not only its order.** A Row's
                    // `textDirection` places its children but does not
                    // reach inside them: LinearProgressIndicator reads the
                    // ambient direction to paint, so with only the Row
                    // pinned the line still filled from the right in
                    // Arabic while the drag counted from the left (field
                    // report 2026-09-25).
                    return Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: shown,
                                // It thickens under the finger: confirmation
                                // that the drag was caught.
                                minHeight: dragging ? 6 : 3,
                                backgroundColor: MTPalette.serverCardInk
                                    .withValues(alpha: 0.25),
                                valueColor: AlwaysStoppedAnimation(p.accent),
                              ),
                            ),
                          ),
                          if (dragging) ...[
                            const SizedBox(width: MTSpace.sm),
                            Text(
                              mtFormatDuration(state.duration * shown),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MTPalette.serverCardInk,
                              ).tabular,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
