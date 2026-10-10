import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_thumb_pill.dart';

/// A row's thumbnail: the cover in a rounded frame, with the duration and
/// an audio mark over its corners. Shared by the phone row and the
/// tablet's table row, so the two never draw a cover differently.
class MTMediaThumb extends StatelessWidget {
  const MTMediaThumb({
    super.key,
    required this.width,
    required this.height,
    this.duration,
    this.playing = false,
    this.audio = false,
    this.child,
  });

  final double width;
  final double height;
  final String? duration;
  final bool playing;
  final bool audio;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(MTRadius.thumb),
        border: Border.all(color: p.line),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child ?? Icon(Icons.music_note_rounded, size: 20, color: p.ink3),
          if (duration != null)
            PositionedDirectional(
              bottom: 5,
              start: 5,
              child: MTThumbPill.duration(duration!),
            ),
          // Without a cover the placeholder is already a music note, so a
          // second one would only repeat it.
          if (audio && child != null)
            PositionedDirectional(
              bottom: 5,
              end: 5,
              child: MTThumbPill.audio(),
            ),
        ],
      ),
    );
  }
}
