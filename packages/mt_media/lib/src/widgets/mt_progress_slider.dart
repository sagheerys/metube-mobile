import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'media_time.dart';

/// شريط التقدم بمقبض — من مرجع «وهج» (مسار 5px، تعبئة بلون الفعل،
/// مقبض حبري 15px). يُستعمل في شاشة الصوت والفيديو العمودي والعرضي.
class MTProgressSlider extends StatefulWidget {
  const MTProgressSlider({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.buffered,
    this.dark = false,
    this.showRemaining = true,
  });

  final Duration position;
  final Duration? duration;
  final Duration? buffered;
  final ValueChanged<Duration> onSeek;

  /// فوق الفيديو الداكن: حبر كريمي بدل الحبر البني.
  final bool dark;

  /// شاشة الصوت تعرض المتبقي سالباً؛ الفيديو يعرض المدة الكاملة.
  final bool showRemaining;

  @override
  State<MTProgressSlider> createState() => _MTProgressSliderState();
}

class _MTProgressSliderState extends State<MTProgressSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final total = widget.duration ?? Duration.zero;
    final maxMs = total.inMilliseconds.toDouble();
    final positionMs = widget.position.inMilliseconds
        .clamp(0, maxMs < 1 ? 1 : maxMs.toInt())
        .toDouble();
    final value = _dragValue ?? positionMs;
    final onDark = widget.dark;
    final trackInactive =
        onDark ? p.miniInk.withValues(alpha: 0.25) : p.ink.withValues(alpha: 0.1);
    final timeColor = onDark ? p.miniInkMuted : p.ink3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: onDark ? 4 : 5,
            activeTrackColor: p.accent,
            inactiveTrackColor: trackInactive,
            secondaryActiveTrackColor: trackInactive,
            thumbColor: onDark ? p.miniInk : p.ink,
            overlayColor: p.accent.withValues(alpha: 0.12),
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: onDark ? 5.5 : 7.5,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: maxMs < 1 ? 0 : value.clamp(0, maxMs),
            max: maxMs < 1 ? 1 : maxMs,
            secondaryTrackValue: widget.buffered?.inMilliseconds
                .clamp(0, maxMs < 1 ? 1 : maxMs.toInt())
                .toDouble(),
            onChanged: maxMs < 1
                ? null
                : (v) => setState(() => _dragValue = v),
            onChangeEnd: (v) {
              widget.onSeek(Duration(milliseconds: v.round()));
              setState(() => _dragValue = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MTSpace.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mtFormatDuration(Duration(milliseconds: value.round())),
                style: _timeStyle(context, timeColor),
              ),
              Text(
                widget.showRemaining
                    ? mtFormatRemaining(
                        Duration(milliseconds: value.round()), widget.duration)
                    : mtFormatDuration(total),
                style: _timeStyle(context, timeColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// **كان يطلب `tabularFigures` ولا يحصل عليها**: النمط يرث خط النصوص
  /// Tajawal الذي لا يملك جدول `tnum` أصلاً (فحص الملف الثنائي
  /// 2026-09-02)، فتُتجاهل الميزة بصمت ويظل العدّاد يرقص. `.tabular`
  /// ينقله لخط العناوين الذي يدعمها فعلاً.
  TextStyle _timeStyle(BuildContext context, Color color) =>
      Theme.of(context).textTheme.bodySmall!.copyWith(color: color).tabular;
}
