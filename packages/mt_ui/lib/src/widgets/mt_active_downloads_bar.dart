import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// **شريط مُجمِّع للتحميلات النشطة** — بديل تكديس بطاقة لكل مهمة أعلى
/// المكتبة.
///
/// بلاغ المالك 2026-09-03: «عدة تحميلات تظهر كلها في مكتبة التحميلات
/// **وهي موجود لها زر فوق في الأعلى** — أوجد طريقة بحيث ما تتزاحم في
/// مكان واحد». كل بطاقة حية ترتفع ~78 نقطة، فثلاث مهام كانت تدفع
/// المكتبة خارج الشاشة وتترك المستخدم يمرّر ليصل إلى ملفاته.
///
/// القاعدة الآن: مهمة واحدة ⇒ بطاقتها كاملة · أكثر ⇒ **هذا السطر
/// الواحد** يلخّصها ويحيل إلى ورقة الإدارة التي فتحها زر الرأس أصلاً.
class MTActiveDownloadsBar extends StatelessWidget {
  const MTActiveDownloadsBar({
    super.key,
    required this.label,
    required this.actionLabel,
    required this.onTap,
    this.progress,
  });

  /// «٣ تحميلات جارية» — مترجم من التطبيق.
  final String label;

  /// «عرض الكل».
  final String actionLabel;
  final VoidCallback onTap;

  /// متوسط تقدم المهام 0..1، أو null لغير المحدد.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;

    return Material(
      color: p.accentSoft,
      borderRadius: BorderRadius.circular(MTRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MTRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.md + 1, vertical: MTSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MTRadius.card),
            border: Border.all(color: p.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.downloading_rounded, size: 20, color: p.accent),
                  const SizedBox(width: MTSpace.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium!
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (progress != null)
                    Text(
                      '${(progress!.clamp(0, 1) * 100).round()}%',
                      style: text.bodySmall!.copyWith(
                          fontWeight: FontWeight.w700, color: p.accent),
                    ),
                  const SizedBox(width: MTSpace.sm),
                  Text(
                    actionLabel,
                    style: text.labelSmall!.copyWith(
                        color: p.accent, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: MTSpace.xs + 1),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: p.accent.withValues(alpha: 0.16),
                  valueColor: AlwaysStoppedAnimation(p.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
