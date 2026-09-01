import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';

/// أنواع المنصات **بصرياً** — mt_ui لا يعرف mt_core (قاعدة الاعتماد 6)،
/// والتطبيق يحوّل `MediaPlatform` إلى هذا النوع.
enum MTPlatformKind {
  youtube('YT', Color(0xFFA8442F)),
  tiktok('TT', Color(0xFF3E6273)),
  instagram('IG', Color(0xFFA34E68)),
  soundcloud('SC', Color(0xFF9A6B10)),
  x('X', Color(0xFF4A4440)),
  facebook('FB', Color(0xFF3E5273)),
  vimeo('VM', Color(0xFF3E6E73)),
  twitch('TW', Color(0xFF6B4E9A)),
  reddit('RD', Color(0xFFA85A2F)),
  dailymotion('DM', Color(0xFF445A8A)),
  other('•', Color(0x00000000));

  const MTPlatformKind(this.label, this.tint);

  final String label;

  /// درجة نصية دافئة من عائلة وهج (المرجع: pchip في direction-3) —
  /// [other] يسقط إلى ink3 من اللوحة.
  final Color tint;
}

/// شارة المنصة النصية المضغوطة داخل صف بيانات البطاقة.
class MTPlatformChip extends StatelessWidget {
  const MTPlatformChip({super.key, required this.kind});

  final MTPlatformKind kind;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    return Text(
      kind.label,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: kind == MTPlatformKind.other ? x.palette.ink3 : kind.tint,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
