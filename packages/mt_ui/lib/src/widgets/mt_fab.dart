import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_motion.dart';
import 'mt_polish.dart';

/// The approved "add link" button: a rounded rectangular FAB in the accent
/// colour with a translucent icon box. Its label and icon change when a
/// link is waiting in the clipboard.
class MTFab extends StatelessWidget {
  const MTFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  /// The "link ready to paste" state: a paste icon and a colour pulse.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final duration = mtMotionDuration(context, MTMotion.tap);
    final labelStyle = TextStyle(
      fontFamily: MTType.body,
      package: MTType.package,
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: p.onAccent,
    );
    // **The swap between "add link" and "link ready" is animated** (polish
    // 2026-09-04): the colour dissolves, the icons trade places and the
    // width stretches with the label. All three used to jump at once the
    // moment something was copied.
    // **A bound on the width, because nothing else gives it one.** The
    // Scaffold's floating slot lets this button grow as wide as its label
    // wants, so a long label at a large text scale walks off the right of
    // a narrow screen: "Follow a channel" at ×1.3 on 320dp overflowed by
    // 35 pixels (device matrix, 2026-09-20). Today's shipped labels are
    // short enough, but م-50 adds languages whose words are not.
    final media = MediaQuery.of(context);
    final maxWidth = media.size.width - MTSpace.pagePad * 2;

    return MTPressable(
      child: AnimatedContainer(
        duration: duration,
        curve: MTMotion.entrance,
        decoration: BoxDecoration(
          color: highlighted ? p.accentDeep : p.accent,
          borderRadius: BorderRadius.circular(MTRadius.fab),
          boxShadow: MTShadow.fab(p),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(MTRadius.fab),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(MTRadius.fab),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MTSpace.md + 1,
                MTSpace.md + 1,
                MTSpace.xl,
                MTSpace.md + 1,
              ),
              child: AnimatedSize(
                duration: duration,
                curve: MTMotion.entrance,
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: p.onAccent.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: MTIconSwap(
                            icon: highlighted
                                ? Icons.content_paste_go_rounded
                                : icon,
                            size: 17,
                            color: p.onAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: MTSpace.sm),
                      // **Flexible, so the label yields before the row
                      // does.** The icon box keeps its size; only the words
                      // are shortened, and only on the screens where they
                      // would not have fitted at all.
                      Flexible(
                        child: MTAnimatedSwap(
                          child: Text(
                            label,
                            key: ValueKey(label),
                            style: labelStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
