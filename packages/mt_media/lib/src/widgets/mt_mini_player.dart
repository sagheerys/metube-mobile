import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../playback/audio_handler.dart';
import 'mt_up_next_list.dart';

/// المشغل المصغر (م-22): شريط دائم أسفل الشاشات الرئيسية عند وجود
/// تشغيل — غلاف، عنوان، تشغيل/إيقاف، تقدم، سحب للإغلاق، ونقرة تفتح
/// شاشة الصوت.
///
/// **فخ §6.5:** الظهور مرهون بـ `mediaItem != null` — لا بـ
/// `processingState` — وإلا بقي شبح بعد الإيقاف.
class MTMiniPlayer extends StatelessWidget {
  const MTMiniPlayer({
    super.key,
    required this.handler,
    required this.onOpen,
    this.artwork,
    this.margin = const EdgeInsets.fromLTRB(
        MTSpace.md, 0, MTSpace.md, MTSpace.sm),
  });

  final MTAudioHandler handler;
  final VoidCallback onOpen;
  final MTArtworkBuilder? artwork;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        builder: (context, snapshot) {
          final item = snapshot.data;
          if (item == null) return const SizedBox.shrink();
          return Padding(
            padding: margin,
            child: _Bar(
              handler: handler,
              onOpen: onOpen,
              artwork: artwork,
              title: item.title,
              subtitle: item.artist,
              current: handler.currentItem,
            ),
          );
        },
      );
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.handler,
    required this.onOpen,
    required this.title,
    this.subtitle,
    this.artwork,
    this.current,
  });

  final MTAudioHandler handler;
  final VoidCallback onOpen;
  final String title;
  final String? subtitle;
  final MTArtworkBuilder? artwork;
  final PlaylistItem? current;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l10n = context.mtl;

    return Dismissible(
      key: const ValueKey('mt-mini-player'),
      direction: DismissDirection.down,
      onDismissed: (_) => handler.stop(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(MTRadius.mini),
          child: Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: MTSpace.sm),
            decoration: BoxDecoration(
              color: p.miniBg,
              borderRadius: BorderRadius.circular(MTRadius.mini),
              boxShadow: MTShadow.mini(p),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: p.miniInk.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(MTRadius.thumb),
                      ),
                      child: current != null && artwork != null
                          ? artwork!(context, current!)
                          : Icon(Icons.music_note_rounded,
                              size: 18, color: p.miniInkMuted),
                    ),
                    const SizedBox(width: MTSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium!.copyWith(
                                  color: p.miniInk,
                                  fontWeight: FontWeight.w700)),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall!
                                    .copyWith(color: p.miniInkMuted)),
                        ],
                      ),
                    ),
                    _PlayButton(handler: handler, palette: p, label: l10n.play),
                    IconButton(
                      onPressed: handler.stop,
                      tooltip: l10n.closePlayer,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded,
                          size: 20, color: p.miniInkMuted),
                    ),
                  ],
                ),
                _Progress(handler: handler, palette: p),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.handler,
    required this.palette,
    required this.label,
  });

  final MTAudioHandler handler;
  final MTPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) => StreamBuilder<PlaybackState>(
        stream: handler.playbackState,
        builder: (context, snapshot) {
          final playing = snapshot.data?.playing ?? false;
          return IconButton(
            onPressed: playing ? handler.pause : handler.play,
            tooltip: label,
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 28,
              color: palette.accent,
            ),
          );
        },
      );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.handler, required this.palette});

  final MTAudioHandler handler;
  final MTPalette palette;

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
        stream: handler.positionStream,
        builder: (context, snapshot) {
          final total = handler.mediaItem.value?.duration;
          final position = snapshot.data ?? Duration.zero;
          final value = total == null || total.inMilliseconds <= 0
              ? 0.0
              : (position.inMilliseconds / total.inMilliseconds).clamp(0, 1)
                  .toDouble();
          return Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 2.5,
                backgroundColor: palette.miniInk.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation(palette.accent),
              ),
            ),
          );
        },
      );
}
