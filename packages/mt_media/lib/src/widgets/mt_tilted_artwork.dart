import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import 'mt_up_next_list.dart';

/// غلاف شاشة الصوت: لوحة مائلة **-1.5°** داخل إطار مائل **+1°** —
/// عنصر هوية معتمد في سجل §4 («غلاف مشغل الصوت مائل داخل إطار»).
class MTTiltedArtwork extends StatelessWidget {
  const MTTiltedArtwork({
    super.key,
    required this.item,
    this.artwork,
    this.size = 296,
  });

  final PlaylistItem item;
  final MTArtworkBuilder? artwork;
  final double size;

  static const double _tilt = -1.5 * math.pi / 180;
  static const double _frameTilt = 1 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: _tilt,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: p.cardAlt,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: p.accentDeep.withValues(alpha: 0.4),
                    blurRadius: 60,
                    offset: const Offset(0, 30),
                    spreadRadius: -18,
                  ),
                ],
              ),
              child: artwork?.call(context, item) ??
                  Center(
                    child: Icon(
                      item.isAudio
                          ? Icons.graphic_eq_rounded
                          : Icons.movie_rounded,
                      size: size * 0.22,
                      color: p.ink3,
                    ),
                  ),
            ),
          ),
          Positioned(
            left: -9,
            right: -9,
            top: -9,
            bottom: -9,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: _frameTilt,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: p.line2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// رقاقة المصدر: «بث من السيرفر» أو «تشغيل من جهازك» (م-19 مرئية).
class MTSourceChip extends StatelessWidget {
  const MTSourceChip({super.key, required this.local});

  final bool local;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    final (bg, fg) = local
        ? (p.offlineSoft, p.offlineInk)
        : (p.onServerSoft, p.onServerInk);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: MTSpace.md, vertical: MTSpace.xxs + 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MTRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            local ? Icons.download_done_rounded : Icons.rss_feed_rounded,
            size: 13,
            color: fg,
          ),
          const SizedBox(width: MTSpace.xxs + 2),
          Text(
            local ? l10n.playingFromDevice : l10n.streamingFromServer,
            style: Theme.of(context)
                .textTheme
                .labelSmall!
                .copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
