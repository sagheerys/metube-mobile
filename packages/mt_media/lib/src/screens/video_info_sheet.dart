import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../video/mt_video_session.dart';
import '../widgets/media_time.dart';
import '../widgets/mt_chapters.dart';
import '../widgets/mt_player_controls_row.dart';
import '../widgets/mt_queue_panel.dart';
import '../widgets/mt_up_next_list.dart';
import 'mt_video_screen.dart';
import 'video_actions_row.dart';

/// The light sheet under the portrait video (Wahaj reference B): title,
/// then metadata, then actions, then mode and speed, then the "up next"
/// section.
class MTVideoInfoSheet extends StatelessWidget {
  const MTVideoInfoSheet({
    super.key,
    required this.session,
    this.actions = const [],
    this.artwork,
    this.subtitleBuilder,
    this.byline,
    this.onShowPlaylist,
    this.playlistName,
    this.chapters,
    this.chaptersFolded,
  });

  final MTVideoSession session;
  final List<MTPlayerAction> actions;
  final MTArtworkBuilder? artwork;
  final String Function(BuildContext context, PlaylistItem item)?
  subtitleBuilder;
  final VoidCallback? onShowPlaylist;

  /// A line under the title an app adds, such as the clip's channel.
  final Widget Function(BuildContext context, PlaylistItem item)? byline;
  final String? playlistName;

  /// See [MTVideoScreen.chapters].
  final List<MTChapter> Function(PlaylistItem item)? chapters;
  final ValueNotifier<bool>? chaptersFolded;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final item = session.current;
    if (item == null) return const SizedBox.shrink();
    final ordered = session.orderedItems;
    final currentIndex = ordered.indexWhere(
      (i) => i.canonicalUrl == item.canonicalUrl,
    );

    return Transform.translate(
      offset: const Offset(0, -14),
      child: Container(
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MTRadius.sheet - 4),
          ),
        ),
        // The margins are inside the list, not around it: a list clips what
        // passes its edges, and the actions row runs out to the screen's.
        padding: const EdgeInsets.only(top: MTSpace.xl),
        child: CustomScrollView(
          slivers: [
            for (final sliver in [
              SliverList.list(
                children: [
                  ..._top(context, item),
                  const SizedBox(height: MTSpace.md),
                  MTQueueHeader(
                    count: ordered.length,
                    playlistName: playlistName,
                    onShowAll: onShowPlaylist,
                  ),
                  const SizedBox(height: MTSpace.xs),
                ],
              ),
              MTUpNextSliver(
                items: ordered,
                currentIndex: currentIndex,
                artwork: artwork,
                paused: !session.isPlaying,
                onTap: (index) =>
                    session.jumpTo(session.items.indexOf(ordered[index])),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: MTSpace.xl)),
            ])
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MTSpace.pagePad,
                ),
                sliver: sliver,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _top(BuildContext context, PlaylistItem item) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return [
      // Copied to search for it elsewhere (owner's request 2026-11-11).
      MTForeignText(
        item.title,
        maxLines: 2,
        selectable: true,
        style: text.titleMedium!.copyWith(fontSize: 16),
      ),
      if (subtitleBuilder != null) ...[
        const SizedBox(height: MTSpace.xxs),
        Text(
          subtitleBuilder!(context, item),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall!.copyWith(color: p.ink3),
        ),
      ],
      ?byline?.call(context, item),
      if (actions.isNotEmpty) ...[
        const SizedBox(height: MTSpace.md),
        MTVideoActionsRow(actions: actions),
      ],
      const SizedBox(height: MTSpace.md),
      _ModeRow(session: session),
      const SizedBox(height: MTSpace.md),
      Divider(color: p.line, height: 1),
      if (chapters?.call(item) ?? const <MTChapter>[] case final chapters
          when chapters.isNotEmpty) ...[
        const SizedBox(height: MTSpace.lg),
        MTChapterSection(
          chapters: chapters,
          current: mtChapterAt(chapters, session.position),
          onSeek: session.seek,
          folded: chaptersFolded,
          onShowAll: () => showMTChapterSheet(
            context,
            chapters: chapters,
            ticks: session,
            position: () => session.position,
            onSeek: session.seek,
          ),
        ),
      ],
    ];
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.session});

  final MTVideoSession session;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l10n = context.mtl;
    final speed = session.controller?.value.playbackSpeed ?? 1.0;

    return Row(
      children: [
        // The label gives way first when the row is short of room (a side
        // panel, a large system font): the chips are what the user taps.
        Flexible(
          child: Text(
            '${l10n.playModeLabel}:',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall!.copyWith(color: p.ink3),
          ),
        ),
        const SizedBox(width: MTSpace.xs),
        _Chip(
          label: mtPlayModeLabel(context, session.playMode),
          selected: true,
          onTap: () => session.setPlayMode(session.playMode.next),
        ),
        const SizedBox(width: MTSpace.xs),
        _Chip(
          label: l10n.shuffle,
          selected: session.shuffleEnabled,
          onTap: () => session.setShuffle(!session.shuffleEnabled),
        ),
        const Spacer(),
        _Chip(
          label: '${mtFormatSpeed(speed)}×',
          selected: false,
          onTap: () => session.setSpeed(mtNextSpeed(speed)),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    // The chosen chip is filled with the ink, as every chosen chip is: the
    // action colour is kept for the one thing to press.
    return Material(
      color: selected ? p.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(MTRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MTRadius.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MTSpace.md,
            vertical: MTSpace.xs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MTRadius.chip),
            border: Border.all(color: selected ? p.ink : p.line2),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: selected ? p.bg : p.ink2,
              fontWeight: selected ? FontWeight.w700 : null,
            ),
          ),
        ),
      ),
    );
  }
}
