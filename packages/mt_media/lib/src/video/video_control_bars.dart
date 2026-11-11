import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/play_mode.dart';
import '../widgets/media_time.dart';
import '../widgets/mt_chapter_label.dart';
import '../widgets/mt_chapters.dart';
import '../widgets/mt_extra_button.dart';
import '../widgets/mt_player_controls_row.dart';
import '../widgets/mt_progress_slider.dart';
import 'mt_video_session.dart';
import 'video_buttons.dart';
import 'caption_buttons.dart';
import 'mt_captions.dart';
import 'mt_picture_in_picture.dart';

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
    this.captions,
  });

  final MTVideoSession session;
  final VoidCallback onBack;

  /// Gives a CC button that shows and hides the subtitles; null for a clip
  /// without any.
  final MTCaptions? captions;
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
          l10n.playlistOf(session.currentIndex + 1, session.items.length),
        ),
      ?membershipLine,
    ];

    return Row(
      children: [
        MTVideoIconButton(
          icon: fullscreen ? MTIcons.back : MTIcons.chevronDown,
          onTap: onBack,
          tooltip: l10n.dismiss,
        ),
        const SizedBox(width: MTSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              MTForeignText(
                item?.title ?? '',
                maxLines: 1,
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
        if (captions case final captions?) ...[
          const SizedBox(width: MTSpace.xs),
          MTCaptionButtons(captions: captions),
        ],
        // Only once the user has turned picture in picture on.
        ValueListenableBuilder(
          valueListenable: MTPictureInPicture.instance.enabled,
          builder: (context, on, _) => on
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(start: MTSpace.xs),
                  child: MTVideoIconButton(
                    icon: MTIcons.pip,
                    onTap: () => MTPictureInPicture.instance.enter(
                      aspect: mtPictureShape(session),
                    ),
                    tooltip: l10n.pictureInPicture,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: MTSpace.xs),
        MTVideoSpeedButton(session: session),
        const SizedBox(width: MTSpace.xs),
        if (onLock != null) ...[
          MTVideoIconButton(
            icon: MTIcons.lock,
            onTap: onLock!,
            tooltip: l10n.lockTouch,
          ),
          const SizedBox(width: MTSpace.xs),
        ],
        MTVideoIconButton(
          icon: fullscreen ? MTIcons.collapse : MTIcons.fullscreen,
          onTap: onToggleFullscreen,
          tooltip: fullscreen ? l10n.exitFullscreen : l10n.enterFullscreen,
        ),
      ],
    );
  }
}

/// The bottom bar: the time, play modes and the queue button in one row,
/// then a thin bar along the bottom edge of the picture, so less of the
/// picture and the subtitle above it is covered (owner's request
/// 2026-11-11, in full screen and under the video alike).
class MTVideoBottomBar extends StatelessWidget {
  const MTVideoBottomBar({
    super.key,
    required this.session,
    required this.onQueue,
    this.compactModes = false,
    this.extra,
    this.chapters = const [],
    this.onChapters,
  });

  final MTVideoSession session;
  final VoidCallback onQueue;
  final bool compactModes;

  /// A button the app adds before the queue button.
  final MTExtraAction? extra;

  /// The clip's chapters: cuts in the track, and the one playing beside
  /// the time, which opens the list through [onChapters].
  final List<MTChapter> chapters;
  final VoidCallback? onChapters;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final inkMuted = MTPalette.serverCardInk.withValues(alpha: 0.85);
    final value = session.controller?.value;

    final slider = MTProgressSlider(
      position: session.position,
      duration: session.duration,
      buffered: value == null || value.buffered.isEmpty
          ? null
          : value.buffered.last.end,
      dark: true,
      showRemaining: false,
      // The row above already says "0:12 / 0:36"; the slider's own pair
      // said it a second time.
      showTimes: false,
      thin: true,
      marks: [for (final chapter in chapters) chapter.start],
      onSeek: session.seek,
    );
    final row = _row(context, l10n, text, inkMuted);
    return Column(mainAxisSize: MainAxisSize.min, children: [row, slider]);
  }

  Widget _row(
    BuildContext context,
    MTLocalizations l10n,
    TextTheme text,
    Color inkMuted,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: MTSpace.sm),
    child: Row(
      children: [
        Text(
          // Isolated left to right: in an Arabic line the pair read
          // "3:02 / 1:20", the length before the position (field
          // report 2026-10-04).
          mtLtrRun(
            '${mtFormatDuration(session.position)} / '
            '${mtFormatDuration(session.duration ?? Duration.zero)}',
          ),
          // A counter live on every frame. Without fixed-width digits
          // the text stretches and shrinks and the whole line dances
          // (review 2026-09-02).
          style: text.labelSmall!.copyWith(color: inkMuted).tabular,
        ),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: chapters.isEmpty || onChapters == null
                ? null
                : MTChapterLabel(
                    chapters: chapters,
                    position: session.position,
                    onTap: onChapters!,
                  ),
          ),
        ),
        MTVideoIconButton(
          icon: mtPlayModeIcon(session.playMode),
          onTap: () => session.setPlayMode(session.playMode.next),
          tooltip: mtPlayModeLabel(context, session.playMode),
          size: 32,
          active: session.playMode != PlayMode.autoNext,
        ),
        const SizedBox(width: MTSpace.xxs + 2),
        MTVideoIconButton(
          icon: MTIcons.shuffle,
          onTap: () => session.setShuffle(!session.shuffleEnabled),
          tooltip: l10n.shuffle,
          size: 32,
          active: session.shuffleEnabled,
        ),
        if (extra case final extra?) ...[
          const SizedBox(width: MTSpace.xxs + 2),
          // In the style of its neighbours: beside repeat and shuffle,
          // which light up when on, a filled button read as switched
          // on (field report 2026-09-30).
          MTVideoIconButton(
            icon: extra.icon,
            onTap: extra.onTap,
            tooltip: extra.label,
            size: 32,
          ),
        ],
        const SizedBox(width: MTSpace.xxs + 2),
        MTVideoIconButton(
          icon: MTIcons.queue,
          onTap: onQueue,
          tooltip: l10n.queueLabel,
          size: 32,
        ),
      ],
    ),
  );
}
