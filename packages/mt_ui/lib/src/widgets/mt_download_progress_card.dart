import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// بطاقة تحميل حية «وهج»: أرضية soft بلون الفعل + شريط تقدم + إلغاء.
/// نص الحالة (المرحلة/الخطأ) يأتي مترجماً من التطبيق.
class MTDownloadProgressCard extends StatelessWidget {
  const MTDownloadProgressCard({
    super.key,
    required this.title,
    required this.statusText,
    this.progress,
    this.isError = false,
    this.onCancel,
    this.thumbnail,
  });

  final String title;
  final String statusText;

  /// 0..1 أو null لغير المحدد (مرحلة الإضافة/الانتظار).
  final double? progress;
  final bool isError;
  final VoidCallback? onCancel;
  final Widget? thumbnail;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final tint = isError ? p.err : p.accent;
    final softInk = isError ? p.err : p.accentInk;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: MTSpace.md + 1, vertical: MTSpace.md),
      decoration: BoxDecoration(
        color: isError
            ? p.err.withValues(alpha: 0.08)
            : p.accentSoft,
        borderRadius: BorderRadius.circular(MTRadius.card),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(MTRadius.thumb),
              border: Border.all(color: tint.withValues(alpha: 0.25)),
            ),
            child: thumbnail ??
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.download_rounded,
                  size: 22,
                  color: tint,
                ),
          ),
          const SizedBox(width: MTSpace.md - 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium!
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(color: softInk)),
                if (!isError) ...[
                  const SizedBox(height: MTSpace.xs + 1),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: tint.withValues(alpha: 0.16),
                      valueColor: AlwaysStoppedAnimation(tint),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onCancel != null) ...[
            const SizedBox(width: MTSpace.sm),
            InkWell(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(MTRadius.chip),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: p.card.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(MTRadius.chip),
                ),
                child: Icon(Icons.close_rounded, size: 16, color: p.ink3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
