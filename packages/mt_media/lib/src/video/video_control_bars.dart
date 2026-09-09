import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../widgets/media_time.dart';
import '../widgets/mt_player_controls_row.dart';
import '../widgets/mt_progress_slider.dart';
import 'mt_video_session.dart';
import 'video_buttons.dart';

/// The top bar: back, the title and its position in the list, speed, lock,
/// full screen.
class MTVideoTopBar extends StatelessWidget {
  const MTVideoTopBar({
    super.key,
    required this.session,
    required this.onBack,
    required this.onToggleFullscreen,
    required this.fullscreen,
    this.onLock,
    this.playlistName,
    this.membershipLine,
  });

  final MTVideoSession session;
  final VoidCallback onBack;
  final VoidCallback onToggleFullscreen;
  final bool fullscreen;
  final VoidCallback? onLock;
  final String? playlistName;

  /// **Where the clip belongs** (field report 2026-09-04): "which tag it is
  /// under, or which playlist it was added to". Built in the app and shown
  /// under the title in landscape, where there is no info sheet at all.
  final String? membershipLine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final item = session.current;
    final subtitleParts = [
      if (playlistName != null) '«$playlistName»',
      if (session.items.length > 1)
        mtLtrRun(
            l10n.playlistOf(session.currentIndex + 1, session.items.length)),
      ?membershipLine,
    ];

    return Row(
      children: [
        MTVideoIconButton(
          icon: fullscreen
              ? Icons.arrow_back_rounded
              : Icons.keyboard_arrow_down_rounded,
          onTap: onBack,
          tooltip: l10n.dismiss,
        ),
        const SizedBox(width: MTSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item?.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium!.copyWith(
                  color: MTPalette.serverCardInk,
                  fontSize: 13.5,
                ),
              ),
              if (subtitleParts.isNotEmpty)
                Text(
                  subtitleParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall!.copyWith(
                    color: MTPalette.serverCardInk.withValues(alpha: 0.45),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: MTSpace.xs),
        MTVideoSpeedButton(session: session),
        const SizedBox(width: MTSpace.xs),
        if (onLock != null) ...[
          MTVideoIconButton(
            icon: Icons.lock_outline_rounded,
            onTap: onLock!,
            tooltip: l10n.lockTouch,
          ),
          const SizedBox(width: MTSpace.xs),
        ],
        MTVideoIconButton(
          icon: fullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          onTap: onToggleFullscreen,
          tooltip: fullscreen ? l10n.exitFullscreen : l10n.enterFullscreen,
        ),
      ],
    );
  }
}

/// Screen centre: ten seconds back and forward around a play button in the
/// accent colour.
class MTVideoCenterControls extends StatelessWidget {
  const MTVideoCenterControls({super.key, required this.session});

  final MTVideoSession session;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    // The same rule as the audio bar: transport glyphs do not mirror with
    // the
    // language, and `replay_10`/`forward_10` carry the number "10", which
    // mirroring would invert.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Seek(
            icon: Icons.replay_10_rounded,
            label: l10n.seekBackward10,
            onTap: () => session.seekBy(const Duration(seconds: -10)),
          ),
          const SizedBox(width: MTSpace.xxl),
          Material(
            color: p.accent.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: session.playPause,
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 58,
                height: 58,
                child: Icon(
                  session.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 26,
                  color: p.onAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: MTSpace.xxl),
          _Seek(
            icon: Icons.forward_10_rounded,
            label: l10n.seekForward10,
            onTap: () => session.seekBy(const Duration(seconds: 10)),
          ),
        ],
      ),
    );
  }
}

class _Seek extends StatelessWidget {
  const _Seek({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: label,
    icon: Icon(icon, size: 28, color: MTPalette.serverCardInk),
  );
}

/// The bottom bar: progress, times, play modes and the queue button.
class MTVideoBottomBar extends StatelessWidget {
  const MTVideoBottomBar({
    super.key,
    required this.session,
    required this.onQueue,
    this.compactModes = false,
  });

  final MTVideoSession session;
  final VoidCallback onQueue;
  final bool compactModes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final inkMuted = MTPalette.serverCardInk.withValues(alpha: 0.85);
    final value = session.controller?.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MTProgressSlider(
          position: session.position,
          duration: session.duration,
          buffered: value == null || value.buffered.isEmpty
              ? null
              : value.buffered.last.end,
          dark: true,
          showRemaining: false,
          onSeek: session.seek,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MTSpace.sm),
          child: Row(
            children: [
              Text(
                '${mtFormatDuration(session.position)} / '
                '${mtFormatDuration(session.duration ?? Duration.zero)}',
                // A counter live on every frame. Without fixed-width digits
                // the text
                // stretches and shrinks and the whole line dances (review
                // 2026-09-02).
                style: text.labelSmall!.copyWith(color: inkMuted).tabular,
              ),
              const Spacer(),
              MTVideoIconButton(
                icon: mtPlayModeIcon(session.playMode),
                onTap: () => session.setPlayMode(session.playMode.next),
                tooltip: mtPlayModeLabel(context, session.playMode),
                size: 32,
              ),
              const SizedBox(width: MTSpace.xxs + 2),
              MTVideoIconButton(
                icon: Icons.shuffle_rounded,
                onTap: () => session.setShuffle(!session.shuffleEnabled),
                tooltip: l10n.shuffle,
                size: 32,
                active: session.shuffleEnabled,
              ),
              const SizedBox(width: MTSpace.xxs + 2),
              MTVideoIconButton(
                icon: Icons.queue_music_rounded,
                onTap: onQueue,
                tooltip: l10n.queueLabel,
                size: 32,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
