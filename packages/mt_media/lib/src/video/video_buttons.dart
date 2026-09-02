import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/play_mode.dart';
import '../widgets/media_time.dart';
import 'mt_video_session.dart';

/// أزرار أدوات الفيديو المستقلة — فُصلت عن `video_control_bars.dart`
/// عند إضافة زر السرعة (القاعدة 4: حدّ الأسطر).

/// أزرار الأدوات فوق الفيديو: مربعات داكنة شبه شفافة بحبر كريمي.
class MTVideoIconButton extends StatelessWidget {
  const MTVideoIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 36,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? p.accent.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(MTRadius.field - 1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MTRadius.field - 1),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.42,
              color: MTPalette.serverCardInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// زر السرعة في **أدوات المشغل** (فحص 2026-09-02).
///
/// **تصحيح لملاحظة أولى خاطئة:** ظننت السرعة بلا باب إطلاقاً، والصحيح
/// أن لها رقاقة في ورقة معلومات الفيديو أسفل الشاشة. لكن الورقة **لا
/// وجود لها في ملء الشاشة** — وهو بالضبط الوضع الذي تريد فيه إبطاء درس
/// أو تسريع مقدمة. فالزر هنا يسدّ فجوة حقيقية لا فجوة متوهَّمة.
///
/// النقرة **تدوّر** عبر [mtNextSpeed] — نفس سلوك مشغل الصوت والورقة
/// حرفاً بحرف كي لا يتعلم المستخدم قاعدتين لنفس الفكرة.
class MTVideoSpeedButton extends StatelessWidget {
  const MTVideoSpeedButton({super.key, required this.session});

  final MTVideoSession session;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final speed =
        session.controller?.value.playbackSpeed ?? PlaybackSpeeds.normal;
    final normal = (speed - PlaybackSpeeds.normal).abs() < 0.01;
    return Tooltip(
      message: context.mtl.playbackSpeed,
      child: Material(
        // السرعة غير الطبيعية **حالة مستمرة** يجب أن تُرى بلا قراءة:
        // لون الفعل يقول «هذا المقطع لا يعمل بسرعته الأصلية».
        color: normal
            ? Colors.black.withValues(alpha: 0.4)
            : p.accent.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(MTRadius.field - 1),
        child: InkWell(
          onTap: () => session.setSpeed(mtNextSpeed(speed)),
          borderRadius: BorderRadius.circular(MTRadius.field - 1),
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MTSpace.sm),
              child: Center(
                child: Text(
                  '${mtFormatSpeed(speed)}×',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium!
                      .copyWith(
                        color: normal ? MTPalette.serverCardInk : p.onAccent,
                        fontWeight: FontWeight.w700,
                      )
                      .tabular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
