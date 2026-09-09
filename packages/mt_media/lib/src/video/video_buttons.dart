import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/play_mode.dart';
import '../widgets/media_time.dart';
import 'mt_video_session.dart';

/// The standalone video chrome buttons, split out of
/// `video_control_bars.dart` when the speed button was added (rule 4, the
/// size limit).

/// The chrome buttons over the video: semi-transparent dark squares with
/// cream ink.
class MTVideoIconButton extends StatelessWidget {
  const MTVideoIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 36,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? p.accent.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(MTRadius.field - 1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MTRadius.field - 1),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.42,
              color: MTPalette.serverCardInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// The speed button in **the player chrome** (review 2026-09-02).
///
/// **Correcting an initial mistaken note:** the first reading was that
/// speed had no entry point at all, when in fact it has a chip in the video
/// info sheet at the bottom of the screen. But that sheet **does not exist
/// in full screen**, which is exactly the situation where you want to slow
/// a lesson down or speed an introduction up. So this button fills a real
/// gap rather than an imagined one.
///
/// A tap **cycles** through [mtNextSpeed], the same behaviour as the audio
/// player and the sheet, word for word, so the user never learns two rules
/// for the same idea.
class MTVideoSpeedButton extends StatelessWidget {
  const MTVideoSpeedButton({super.key, required this.session});

  final MTVideoSession session;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final speed =
        session.controller?.value.playbackSpeed ?? PlaybackSpeeds.normal;
    final normal = (speed - PlaybackSpeeds.normal).abs() < 0.01;
    return Tooltip(
      message: context.mtl.playbackSpeed,
      child: Material(
        // A non-normal speed is **a persistent state** that should be
        // visible without reading: the accent colour says "this clip is not
        // running at its original speed".
        color: normal
            ? Colors.black.withValues(alpha: 0.4)
            : p.accent.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(MTRadius.field - 1),
        child: InkWell(
          onTap: () => session.setSpeed(mtNextSpeed(speed)),
          borderRadius: BorderRadius.circular(MTRadius.field - 1),
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MTSpace.sm),
              child: Center(
                child: Text(
                  '${mtFormatSpeed(speed)}×',
                  style: Theme.of(context).textTheme.labelMedium!
                      .copyWith(
                        color: normal ? MTPalette.serverCardInk : p.onAccent,
                        fontWeight: FontWeight.w700,
                      )
                      .tabular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
