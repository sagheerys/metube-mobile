import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import 'media_time.dart';

/// المصغرة يبنيها التطبيق (cached_network_image أو ملف محلي) — mt_media
/// لا يعرف حزمة الصور ولا السيرفر.
typedef MTArtworkBuilder = Widget Function(
    BuildContext context, PlaylistItem item);

/// صفوف «التالي» — نفس المحتوى في الأشكال الثلاثة (م-38): قسم تحت
/// الفيديو العمودي · لوحة جانبية في العرضي · ورقة سفلية في الصوتي.
class MTUpNextList extends StatelessWidget {
  const MTUpNextList({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.artwork,
    this.dark = false,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<PlaylistItem> items;

  /// الفهرس داخل [items] للعنصر قيد التشغيل (-1 إن لا شيء).
  final int currentIndex;
  final ValueChanged<int> onTap;
  final MTArtworkBuilder? artwork;
  final bool dark;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) => ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (context, index) => _UpNextRow(
          item: items[index],
          playing: index == currentIndex,
          artwork: artwork,
          dark: dark,
          onTap: () => onTap(index),
        ),
      );
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({
    required this.item,
    required this.playing,
    required this.dark,
    required this.onTap,
    this.artwork,
  });

  final PlaylistItem item;
  final bool playing;
  final bool dark;
  final VoidCallback onTap;
  final MTArtworkBuilder? artwork;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final ink = dark ? p.miniInk : p.ink;
    final muted = dark ? p.miniInkMuted : p.ink3;
    final line = dark ? p.miniInk.withValues(alpha: 0.08) : p.line;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: MTSpace.sm),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: line)),
        ),
        child: Row(
          children: [
            Container(
              width: dark ? 58 : 74,
              height: dark ? 36 : 46,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: dark ? p.miniInk.withValues(alpha: 0.1) : p.cardAlt,
                borderRadius: BorderRadius.circular(MTRadius.thumb - 2),
                border: Border.all(color: line),
              ),
              child: artwork?.call(context, item) ??
                  Icon(
                    item.isAudio
                        ? Icons.music_note_rounded
                        : Icons.movie_rounded,
                    size: 16,
                    color: muted,
                  ),
            ),
            const SizedBox(width: MTSpace.sm),
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(
                  fontSize: dark ? 10.5 : 12,
                  color: playing ? p.accentInk : (dark ? p.miniInkMuted : ink),
                  fontWeight: playing ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: MTSpace.xs),
            if (playing)
              const MTEqualizer(size: 11)
            else if (item.duration != null)
              Text(
                mtFormatDuration(item.duration!),
                style: text.labelSmall!.copyWith(color: muted),
              ),
          ],
        ),
      ),
    );
  }
}
