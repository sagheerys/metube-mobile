import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/playlist_item.dart';
import '../screens/mt_video_screen.dart';
import 'reels_overlay.dart';
import 'reels_progress.dart';

/// طبقات مشهد الريلز — الصورة وطبقة المعلومات فوقها.
/// فُصلت عن `mt_reels_player.dart` لحدّ الأسطر (القاعدة 4).

class ReelsVideoLayer extends StatelessWidget {
  const ReelsVideoLayer({
    super.key,
    required this.controller,
    required this.failed,
    required this.onTap,
    required this.onDoubleTap,
  });

  final VideoPlayerController? controller;
  final bool failed;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: failed
            ? Center(
                child: Text(context.mtl.playerError,
                    style: TextStyle(color: MTPalette.serverCardInk)),
              )
            : controller == null || !controller!.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller!.value.size.height,
                      child: VideoPlayer(controller!),
                    ),
                  ),
      );
}

class ReelsOverlayLayer extends StatelessWidget {
  const ReelsOverlayLayer({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    required this.favorite,
    required this.onToggleFavorite,
    required this.actions,
    this.subtitle,
    this.controller,
  });

  final PlaylistItem item;
  final int index;
  final int total;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final List<MTPlayerAction> actions;
  final String? subtitle;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          Positioned.fill(child: _Gradient()),
          PositionedDirectional(
            top: MTSpace.sm,
            start: MTSpace.xs,
            end: MTSpace.xs,
            child: SafeArea(
              child: MTReelsTopBar(
                position: index + 1,
                total: total,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          PositionedDirectional(
            top: 64,
            start: 0,
            end: 0,
            child: Center(
              child: Text(
                '⌃ ${l10n.reelsSwipeHint}',
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: MTPalette.serverCardInk.withValues(alpha: 0.45)),
              ),
            ),
          ),
          PositionedDirectional(
            start: MTSpace.md,
            bottom: 120,
            child: MTReelsRail(
              favorite: favorite,
              onToggleFavorite: onToggleFavorite,
              actions: actions,
            ),
          ),
          PositionedDirectional(
            start: 74,
            end: MTSpace.lg,
            bottom: MTSpace.xxl,
            child: MTReelsInfo(item: item, subtitle: subtitle),
          ),
          PositionedDirectional(
            start: MTSpace.lg,
            end: MTSpace.lg,
            bottom: MTSpace.sm,
            child: ReelsProgressBar(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _Gradient extends StatelessWidget {
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
              stops: const [0, 0.22, 0.55, 1],
            ),
          ),
        ),
      );
}
