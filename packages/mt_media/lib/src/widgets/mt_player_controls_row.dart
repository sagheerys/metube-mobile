import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/play_mode.dart';
import '../playback/audio_handler.dart';

/// The main control row: shuffle, previous, play and pause, next, mode.
/// The play button is a rounded square in the accent colour, as in the
/// Wahaj reference.
class MTPlayerControlsRow extends StatelessWidget {
  const MTPlayerControlsRow({
    super.key,
    required this.handler,
    this.compact = false,
  });

  final MTAudioHandler handler;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    final size = compact ? 58.0 : 72.0;

    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        // **The control bar does not mirror with the language** (field
        // report 2026-09-02: "the skip buttons on the right and left are
        // reversed"). In RTL the row mirrored the *positions* while the
        // arrows stayed as they were, so "previous" sat on the right with
        // its arrow pointing left. And mirroring the icons is no answer:
        // `replay_10` and `forward_10` carry the number "10", which flips
        // with them. Every reference player, YouTube and Spotify among
        // them, pins this bar: transport glyphs are universal, not text
        // read in a direction.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => handler.setShuffle(!handler.shuffleEnabled),
                tooltip: l10n.shuffle,
                icon: Icon(
                  Icons.shuffle_rounded,
                  size: 21,
                  color: handler.shuffleEnabled ? p.accent : p.ink3,
                ),
              ),
              IconButton(
                onPressed: handler.skipToPrevious,
                tooltip: l10n.previous,
                icon: Icon(
                  Icons.skip_previous_rounded,
                  size: 32,
                  color: p.ink2,
                ),
              ),
              _PlayButton(
                size: size,
                playing: playing,
                palette: p,
                label: playing ? l10n.pause : l10n.play,
                onTap: playing ? handler.pause : handler.play,
              ),
              IconButton(
                onPressed: handler.skipToNext,
                tooltip: l10n.next,
                icon: Icon(Icons.skip_next_rounded, size: 32, color: p.ink2),
              ),
              _ModeButton(handler: handler, palette: p),
            ],
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.size,
    required this.playing,
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final double size;
  final bool playing;
  final MTPalette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    // A light shrink while pressed, and play and pause fade and expand
    // (polish 2026-09-04).
    child: MTPressable(
      child: Material(
        color: palette.accent,
        borderRadius: BorderRadius.circular(size / 3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 3),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size / 3),
              boxShadow: MTShadow.fab(palette),
            ),
            child: Center(
              child: MTIconSwap(
                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: size * 0.42,
                color: palette.onAccent,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.handler, required this.palette});

  final MTAudioHandler handler;
  final MTPalette palette;

  @override
  Widget build(BuildContext context) {
    final mode = handler.playMode;
    return IconButton(
      onPressed: () => handler.setPlayMode(mode.next),
      tooltip: mtPlayModeLabel(context, mode),
      icon: Icon(
        mtPlayModeIcon(mode),
        size: 21,
        color: mode == PlayMode.autoNext ? palette.ink3 : palette.accent,
      ),
    );
  }
}

IconData mtPlayModeIcon(PlayMode mode) => switch (mode) {
  PlayMode.autoNext => Icons.playlist_play_rounded,
  PlayMode.repeatOne => Icons.repeat_one_rounded,
  PlayMode.repeatAll => Icons.repeat_rounded,
  PlayMode.stopAtEnd => Icons.stop_circle_outlined,
};

String mtPlayModeLabel(BuildContext context, PlayMode mode) => switch (mode) {
  PlayMode.autoNext => context.mtl.modeAutoNext,
  PlayMode.repeatOne => context.mtl.modeRepeatOne,
  PlayMode.repeatAll => context.mtl.modeRepeatAll,
  PlayMode.stopAtEnd => context.mtl.modeStopAtEnd,
};
