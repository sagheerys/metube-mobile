import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// The small ink pill laid over a thumbnail corner. The list card and the
/// grid card both draw one for the duration and one for the audio mark,
/// and keeping a single definition stops the two copies drifting apart.
class MTThumbPill extends StatelessWidget {
  const MTThumbPill({super.key, required this.child});

  /// The duration label, as tabular digits.
  static Widget duration(String text) =>
      MTThumbPill(child: _DurationText(text));

  /// The mark that tells a song from a video at a glance. A cover image
  /// alone cannot: an audio file from a video site keeps the video's frame
  /// as its artwork.
  static Widget audio() => const MTThumbPill(child: _AudioGlyph());

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: p.ink.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(5),
      ),
      child: child,
    );
  }
}

class _DurationText extends StatelessWidget {
  const _DurationText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      color: MTThemeX.of(context).palette.bg,
    ).tabular,
  );
}

class _AudioGlyph extends StatelessWidget {
  const _AudioGlyph();

  /// Matches the duration text's line height, so the two pills sit level
  /// on the same bottom edge.
  static const double _size = 12;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.music_note_rounded,
    size: _size,
    color: MTThemeX.of(context).palette.bg,
  );
}
