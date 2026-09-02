import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// شريط «رابط جاهز في الحافظة» — يجلس فوق المشغل المصغر.
///
/// عرض بحت: النصوص والأفعال كلها من التطبيق (mt_ui لا يعرف السيرفر).
/// **الفعلان معاً بقصد**: «تحميل» للحالة الشائعة، و«خيارات» لمن يريد
/// جودة مختلفة — لأن التحميل الفوري بلا مخرج يخيف من يشك في جودته.
/// و«تجاهل» شرط: شريط يعود بعد كل رفض يتحول من مساعدة إلى مضايقة.
class MTClipboardBanner extends StatelessWidget {
  const MTClipboardBanner({
    super.key,
    required this.url,
    required this.title,
    required this.downloadLabel,
    required this.optionsLabel,
    required this.onDownload,
    required this.onOptions,
    required this.onDismiss,
  });

  final String url;
  final String title;
  final String downloadLabel;
  final String optionsLabel;
  final VoidCallback onDownload;
  final VoidCallback onOptions;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Material(
      color: p.accentSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.pagePad, MTSpace.sm, MTSpace.sm, MTSpace.sm),
        child: Row(
          children: [
            Icon(Icons.link_rounded, size: 18, color: p.accentInk),
            const SizedBox(width: MTSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: text.labelMedium!.copyWith(color: p.accentInk)),
                  // الرابط **LTR دائماً** ومقصوص من أوله: ذيله (معرّف
                  // المقطع) هو ما يميّزه، وصدره `https://www.` مكرر.
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: text.labelSmall!.copyWith(color: p.ink3),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onOptions, child: Text(optionsLabel)),
            FilledButton(onPressed: onDownload, child: Text(downloadLabel)),
            IconButton(
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: p.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
