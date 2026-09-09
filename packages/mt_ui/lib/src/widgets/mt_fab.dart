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
    // width
    // stretches with the label. All three used to jump at once the moment
    // something was copied.
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
                    MTAnimatedSwap(
                      child: Text(
                        label,
                        key: ValueKey(label),
                        style: labelStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
