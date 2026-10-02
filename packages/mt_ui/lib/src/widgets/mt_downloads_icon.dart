import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// **The downloads button's icon: it moves while something downloads.**
///
/// A number on a still arrow said how many, not that anything was
/// happening; a count stuck on 1 for a minute looked the same as one that
/// was working. While [active] is above zero the arrow drops a few points
/// and fades, then comes back from above, on a calm loop: motion that
/// means "a download is running now". At zero it stands still, so the
/// motion itself is the news.
///
/// The count changes with a short fade instead of a jump. Within the
/// identity's rules: no bounce, durations and curves from [MTMotion], and
/// perfectly still when the system asks to reduce motion.
class MTDownloadsIcon extends StatefulWidget {
  const MTDownloadsIcon({super.key, required this.active});

  /// How many downloads are running.
  final int active;

  /// One drop: long enough to read as calm, short enough to read as busy.
  static const Duration period = Duration(milliseconds: 1600);

  /// How far the arrow drops, in points. Glimpsed, not watched.
  static const double drop = 3;

  @override
  State<MTDownloadsIcon> createState() => _MTDownloadsIconState();
}

class _MTDownloadsIconState extends State<MTDownloadsIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: MTDownloadsIcon.period,
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(MTDownloadsIcon old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final moving = widget.active > 0 && !_still;
    if (moving && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!moving && _loop.isAnimating) {
      // Stops where it stands upright, not half faded.
      _loop
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Badge(
      isLabelVisible: widget.active > 0,
      label: AnimatedSwitcher(
        duration: _still ? Duration.zero : MTMotion.tap,
        switchInCurve: MTMotion.entrance,
        switchOutCurve: MTMotion.exit,
        child: Text('${widget.active}', key: ValueKey(widget.active)),
      ),
      backgroundColor: p.accent,
      textColor: p.onAccent,
      // **Only the arrow moves; the line under it stays** (field report
      // 2026-10-01): a still tray with the arrow dropping into it
      // reads as "downloading", where the whole glyph sliding read as an
      // icon wobbling. One glyph, cut in two at the gap between them.
      child: Stack(
        children: [
          const ClipRect(
            clipper: _Band(top: false),
            child: Icon(Icons.download_rounded),
          ),
          ClipRect(
            clipper: const _Band(top: true),
            child: AnimatedBuilder(
              animation: _loop,
              builder: (context, child) {
                final (offset, opacity) = mtDownloadDrop(_loop.value);
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, offset * MTDownloadsIcon.drop),
                    child: child,
                  ),
                );
              },
              child: const Icon(Icons.download_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

/// Half of the download glyph: the arrow above the cut, or the tray below.
///
/// In Material's glyph the arrow ends at 15.6 and the tray starts at 18, on
/// a 24-point grid; cutting at 17 keeps each whole, and the moving arrow
/// vanishes at the cut as if it went into the tray.
class _Band extends CustomClipper<Rect> {
  const _Band({required this.top});

  final bool top;

  static const double _cut = 17 / 24;

  @override
  Rect getClip(Size size) {
    final cut = size.height * _cut;
    return top
        ? Rect.fromLTRB(0, 0, size.width, cut)
        : Rect.fromLTRB(0, cut, size.width, size.height);
  }

  @override
  bool shouldReclip(_Band old) => old.top != top;
}

/// Where the arrow is at [t] (0 to 1) of one drop, as (offset, opacity):
/// offset from -1 (above) through 0 (at rest) to 1 (dropped).
///
/// Most of the loop it rests in place, fully visible; then it falls and
/// fades, and comes back in from above. Split out so the motion itself is
/// testable, not only that a timer runs.
(double, double) mtDownloadDrop(double t) {
  const rest = 0.45;
  const fall = 0.75;
  if (t < rest) return (0, 1);
  if (t < fall) {
    final k = MTMotion.exit.transform((t - rest) / (fall - rest));
    return (k, 1 - k);
  }
  final k = MTMotion.entrance.transform((t - fall) / (1 - fall));
  return (k - 1, k);
}
