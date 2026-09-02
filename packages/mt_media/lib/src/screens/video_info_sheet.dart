import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../video/mt_video_session.dart';
import '../widgets/media_time.dart';
import '../widgets/mt_player_controls_row.dart';
import '../widgets/mt_queue_panel.dart';
import '../widgets/mt_up_next_list.dart';
import 'mt_video_screen.dart';

/// الورقة الكريمية تحت الفيديو العمودي (مرجع «وهج» B): العنوان ←
/// البيانات ← الأفعال ← الوضع والسرعة ← قسم «التالي» (م-38).
class MTVideoInfoSheet extends StatelessWidget {
  const MTVideoInfoSheet({
    super.key,
    required this.session,
    this.actions = const [],
    this.artwork,
    this.subtitleBuilder,
    this.onShowPlaylist,
    this.onSaveQueueAsPlaylist,
    this.playlistName,
  });

  final MTVideoSession session;
  final List<MTPlayerAction> actions;
  final MTArtworkBuilder? artwork;
  final String Function(BuildContext context, PlaylistItem item)?
      subtitleBuilder;
  final VoidCallback? onShowPlaylist;
  final VoidCallback? onSaveQueueAsPlaylist;
  final String? playlistName;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final item = session.current;
    if (item == null) return const SizedBox.shrink();
    final ordered = session.orderedItems;
    final currentIndex =
        ordered.indexWhere((i) => i.canonicalUrl == item.canonicalUrl);

    return Transform.translate(
      offset: const Offset(0, -14),
      child: Container(
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(MTRadius.sheet - 4)),
        ),
        padding: const EdgeInsets.fromLTRB(
            MTSpace.pagePad, MTSpace.xl, MTSpace.pagePad, 0),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Text(item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium!.copyWith(fontSize: 16)),
            if (subtitleBuilder != null) ...[
              const SizedBox(height: MTSpace.xxs),
              Text(
                subtitleBuilder!(context, item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(color: p.ink3),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: MTSpace.md),
              Row(
                children: [
                  for (final action in actions) ...[
                    if (action != actions.first)
                      const SizedBox(width: MTSpace.xs),
                    Expanded(child: _ActionTile(action: action)),
                  ],
                ],
              ),
            ],
            const SizedBox(height: MTSpace.md),
            _ModeRow(session: session),
            const SizedBox(height: MTSpace.md),
            Divider(color: p.line, height: 1),
            const SizedBox(height: MTSpace.md),
            MTQueuePanel(
              // داخل `ListView` أعلاه — بدون هذا يبتلع مجرى القائمة
              // الداخلية السحبَ فلا يمرَّر قسم «التالي» إطلاقاً.
              nested: true,
              items: ordered,
              currentIndex: currentIndex,
              artwork: artwork,
              playlistName: playlistName,
              onShowAll: onShowPlaylist,
              onSaveAsPlaylist: onSaveQueueAsPlaylist,
              onSelect: (index) =>
                  session.jumpTo(session.items.indexOf(ordered[index])),
            ),
            const SizedBox(height: MTSpace.xl),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final MTPlayerAction action;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final fg = action.highlighted ? p.accentInk : p.ink2;
    return Material(
      color: action.highlighted ? p.accentSoft : p.card,
      borderRadius: BorderRadius.circular(MTRadius.field + 1),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(MTRadius.field + 1),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: MTSpace.sm + 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MTRadius.field + 1),
            border: Border.all(
                color: action.highlighted
                    ? p.accent.withValues(alpha: 0.3)
                    : p.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 17, color: fg),
              const SizedBox(height: MTSpace.xxs + 2),
              Text(
                action.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: fg,
                      fontSize: 9.5,
                      height: 1.35,
                      fontWeight:
                          action.highlighted ? FontWeight.w700 : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صف الوضع والسرعة (مرجع B): رقاقة الوضع الحالي + السرعة في الطرف.
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
        Text('${l10n.playModeLabel}:',
            style: text.labelSmall!.copyWith(color: p.ink3)),
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
    return Material(
      color: selected ? p.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(MTRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MTRadius.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.md, vertical: MTSpace.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MTRadius.chip),
            border: Border.all(color: selected ? p.accent : p.line2),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: selected ? p.accentInk : p.ink2,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
          ),
        ),
      ),
    );
  }
}
