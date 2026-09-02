import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import '../widgets/media_time.dart';

/// شريط تقدّم الريلز — **قابل للسحب** (بلاغ المالك 2026-09-02: «لا
/// تستطيع التقديم والترجيع ولا إمساك العداد»).
///
/// أثناء السحب نعرض موضع الإصبع لا موضع المشغل، وإلا قفز المؤشر للخلف
/// مع كل تحديث من المشغل فبدا الشريط «يقاوم» الإصبع. ومنطقة اللمس
/// **٢٤ نقطة** حول خيط سمكه ٣ — الشريط النحيل جميل ولا يُمسك.
class ReelsProgressBar extends StatefulWidget {
  const ReelsProgressBar({
    super.key,
    this.controller,
    this.onScrubStart,
    this.onScrubEnd,
  });

  final VideoPlayerController? controller;

  /// **الشريط لا يشغّل ولا يوقف بنفسه (العطل ط-3):** مالك الحالة وحده
  /// يعرف تركيز الصوت وقفل الشاشة. [onScrubEnd] يُستدعى عند نهاية
  /// السحب **وعند إلغائه** فلا يبقى المقطع موقوفاً بلا مؤشر.
  final VoidCallback? onScrubStart;
  final VoidCallback? onScrubEnd;

  @override
  State<ReelsProgressBar> createState() => _ReelsProgressBarState();
}

class _ReelsProgressBarState extends State<ReelsProgressBar> {
  double? _dragFraction;

  Duration _durationOf(VideoPlayerController c) => c.value.duration;

  void _seekToFraction(double fraction) {
    final controller = widget.controller;
    if (controller == null) return;
    final total = _durationOf(controller);
    if (total <= Duration.zero) return;
    controller.seekTo(total * fraction.clamp(0, 1));
  }

  /// الكسر من إحداثي أفقي — **يحترم RTL**: أقصى «بداية» الاتجاه = 0.
  double _fractionFrom(Offset local, double width) {
    if (width <= 0) return 0;
    final raw = (local.dx / width).clamp(0.0, 1.0);
    return Directionality.of(context) == TextDirection.rtl ? 1 - raw : raw;
  }

  /// تبديل الصفحة أثناء السحب كان يترك [_dragFraction] عالقاً، فيتجمد
  /// شريط المقطع التالي على كسر قديم.
  @override
  void didUpdateWidget(ReelsProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller && _dragFraction != null) {
      setState(() => _dragFraction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(height: 24);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void update(Offset local) =>
            setState(() => _dragFraction = _fractionFrom(local, width));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) {
            update(d.localPosition);
            widget.onScrubStart?.call();
          },
          onHorizontalDragUpdate: (d) => update(d.localPosition),
          onHorizontalDragEnd: (_) {
            final fraction = _dragFraction;
            if (fraction != null) _seekToFraction(fraction);
            setState(() => _dragFraction = null);
            widget.onScrubEnd?.call();
          },
          onHorizontalDragCancel: () {
            setState(() => _dragFraction = null);
            widget.onScrubEnd?.call();
          },
          // نقرة على الشريط = قفزة مباشرة (بلا سحب).
          onTapDown: (d) {
            final fraction = _fractionFrom(d.localPosition, width);
            _seekToFraction(fraction);
          },
          child: SizedBox(
            height: 24,
            child: Center(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, state, _) {
                  final total = state.duration.inMilliseconds;
                  final playedFraction = total <= 0
                      ? 0.0
                      : (state.position.inMilliseconds / total)
                          .clamp(0.0, 1.0);
                  final dragging = _dragFraction != null;
                  final shown = _dragFraction ?? playedFraction;
                  return Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: shown,
                            // يثخن تحت الإصبع: تأكيد أن السحب أُمسك.
                            minHeight: dragging ? 6 : 3,
                            backgroundColor: MTPalette.serverCardInk
                                .withValues(alpha: 0.25),
                            valueColor: AlwaysStoppedAnimation(p.accent),
                          ),
                        ),
                      ),
                      if (dragging) ...[
                        const SizedBox(width: MTSpace.sm),
                        Text(
                          mtFormatDuration(state.duration * shown),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: MTPalette.serverCardInk,
                          ).tabular,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
