import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/playlist_item.dart';
import '../screens/mt_video_screen.dart';
import 'reels_overlay.dart';

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
                // **`contain` لا `cover`** (بلاغ المالك 2026-09-02: «يقتطع
                // جزءاً من الفيديو ويظهر مكبراً»). `cover` يملأ الشاشة
                // بتكبير المقطع حتى يغطي البعد الأطول ويقصّ الباقي — على
                // هاتف 20:9 يعني قصّ ~20% من مقطع 16:9 رأسي، أي رأس
                // المتحدث. إنستقرام وشورتس يلائمان العرض ويتركان الفراغ
                // للتدرج والأدوات، وهو ما نفعله الآن: **المقاس الأصلي
                // كاملاً بلا اقتطاع**.
                : Center(
                    child: AspectRatio(
                      aspectRatio: controller!.value.aspectRatio,
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
    required this.visible,
    this.subtitle,
  });

  final PlaylistItem item;
  final int index;
  final int total;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final List<MTPlayerAction> actions;
  final String? subtitle;

  /// **الأدوات تختفي بعد لحظة وتعود باللمس** (طلب المالك 2026-09-02).
  /// شريط التقدم وحده يبقى دائماً — فهو خارج هذه الطبقة.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return IgnorePointer(
      // مخفية ⇒ لا تلتقط اللمس، وإلا ابتلع عمود الأفعال الشفاف النقرة
      // التي يريدها المستخدم لإظهار الأدوات.
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
              bottom: 150,
              child: MTReelsRail(
                favorite: favorite,
                onToggleFavorite: onToggleFavorite,
                actions: actions,
              ),
            ),
            // **فوق شريط التقدم لا عليه** (لقطة على المحاكي 2026-09-02):
            // الشريط صار دائم الظهور، فكان الخيط البرتقالي يمر في منتصف
            // عنوان المقطع. 64 = ارتفاع الشريط (24) + هامش الأمان السفلي
            // + فجوة تنفس.
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
