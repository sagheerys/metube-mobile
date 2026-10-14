import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/playlist_item.dart';
import '../screens/mt_video_screen.dart';
import 'mt_video_open.dart';
import 'reels_overlay.dart';

/// The layers of the reels stage: the picture, and the information layer
/// over it. Split out of `mt_reels_player.dart` for the size limit (rule
/// 4).

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
            child: Text(
              context.mtl.playerError,
              style: TextStyle(color: MTPalette.serverCardInk),
            ),
          )
        : controller == null || !controller!.value.isInitialized
        ? const Center(child: CircularProgressIndicator())
        // **`contain`, not `cover`** (field report 2026-09-02: "it
        // cuts part of the video off and shows it enlarged").
        // `cover` fills the screen by enlarging the clip until it
        // covers the longer dimension and crops the rest: on a 20:9
        // phone that means cropping about 20% of a 16:9 portrait
        // clip, which is the speaker's head. Instagram and Shorts
        // fit the width and leave the space to the gradient and the
        // chrome, which is what we do now: **the original framing,
        // entire and uncropped**.
        : Center(
            child: AspectRatio(
              aspectRatio: controller!.value.aspectRatio,
              child: MTVideoView(controller!),
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
    required this.visible,
    this.subtitle,
  });

  final PlaylistItem item;
  final int index;
  final int total;
  final bool favorite;

  /// `null` means no favourite button in the column (see [MTReelsRail]).
  final VoidCallback? onToggleFavorite;
  final List<MTPlayerAction> actions;
  final String? subtitle;

  /// **The chrome hides after a moment and returns on a touch** (requested
  /// 2026-09-02). The progress bar alone is always visible, which is why it
  /// lives outside this layer.
  final bool visible;

  /// What the top bar and the swipe hint under it take, at normal text.
  static const _clearTop = 72.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return IgnorePointer(
      // Hidden means it does not receive touches, or the transparent action
      // column swallows the tap the user meant for showing the chrome.
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: MTMotion.reveal,
        curve: visible ? MTMotion.entrance : MTMotion.exit,
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
            // **Below the top bar rather than behind it** (device check
            // 2026-09-05): the bar is inside a `SafeArea` while the hint
            // sat at a fixed `top: 64`, so the two strings overlapped on a
            // device with a tall status bar. And the chevron was drawn in
            // an Arabic font, where it looked like the digit eight.
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 46),
                  child: Center(
                    child: Text(
                      '↑ ${l10n.reelsSwipeHint}',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: MTPalette.serverCardInk.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // **A ceiling for the side column** (measured 2026-10-14): held
            // from the bottom alone, it climbed over the top bar on a small
            // phone at large text, and a sixth button (the transcript) made
            // it do so at normal text on the smallest phones. Where it fits
            // nothing moves; where it does not, it shrinks to fit.
            PositionedDirectional(
              start: MTSpace.md,
              top: 0,
              bottom: 150,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.textScalerOf(context).scale(_clearTop),
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.bottomStart,
                      child: MTReelsRail(
                        favorite: favorite,
                        onToggleFavorite: onToggleFavorite,
                        actions: actions,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // **Above the progress bar, not on it** (emulator screenshot
            // 2026-09-02): once the bar became permanently visible, the
            // orange line ran straight through the middle of the clip
            // title. 64 clears the bar's 48-point touch strip, both above
            // the bottom safe inset, plus breathing room.
            PositionedDirectional(
              start: 74,
              end: MTSpace.lg,
              bottom: 64,
              child: SafeArea(
                top: false,
                child: MTReelsInfo(item: item, subtitle: subtitle),
              ),
            ),
          ],
        ),
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
