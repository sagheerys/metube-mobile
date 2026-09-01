import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_platform_chip.dart';

/// خيار جودة معروض في الورقة — القيم والنص من التطبيق (mt_ui لا يعرف
/// عقد السيرفر): الرقمية تُمرَّر فقط عندما يكون الرابط YouTube (م-1).
class MTQualityOption {
  const MTQualityOption({required this.value, required this.label});
  final String value;
  final String label;
}

/// ورقة «إضافة رابط» السفلية (قطر 28): حقل الرابط + شارة المنصة
/// المكتشفة + رقاقات الجودة + زر البدء. منطق اللصق والكشف في التطبيق.
class MTUrlInputSheet extends StatelessWidget {
  const MTUrlInputSheet({
    super.key,
    required this.title,
    required this.urlHint,
    required this.controller,
    required this.qualities,
    required this.selectedQuality,
    required this.onQualitySelected,
    required this.startLabel,
    required this.onStart,
    this.platform,
    this.platformLabel,
    this.onUrlChanged,
  });

  final String title;
  final String urlHint;
  final TextEditingController controller;
  final List<MTQualityOption> qualities;
  final String selectedQuality;
  final ValueChanged<String> onQualitySelected;
  final String startLabel;
  final VoidCallback onStart;
  final MTPlatformKind? platform;
  final String? platformLabel;
  final ValueChanged<String>? onUrlChanged;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    final p = x.palette;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: MTSpace.xl,
        right: MTSpace.xl,
        top: MTSpace.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + MTSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: p.line2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: MTSpace.lg),
          Row(
            children: [
              Expanded(child: Text(title, style: text.titleLarge)),
              if (platform != null && platform != MTPlatformKind.other)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: MTSpace.sm, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(MTRadius.chip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MTPlatformChip(kind: platform!),
                      if (platformLabel != null) ...[
                        const SizedBox(width: 5),
                        Text(platformLabel!,
                            style: text.labelSmall!
                                .copyWith(color: p.accentInk)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: MTSpace.lg),
          TextField(
            controller: controller,
            onChanged: onUrlChanged,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            style: text.bodyMedium,
            decoration: InputDecoration(
              hintText: urlHint,
              prefixIcon:
                  Icon(Icons.link_rounded, size: 20, color: p.ink3),
            ),
          ),
          const SizedBox(height: MTSpace.lg),
          Wrap(
            spacing: MTSpace.xs,
            runSpacing: MTSpace.xs,
            children: [
              for (final q in qualities)
                ChoiceChip(
                  label: Text(q.label),
                  selected: q.value == selectedQuality,
                  onSelected: (_) => onQualitySelected(q.value),
                  showCheckmark: false,
                  labelStyle: text.labelMedium!.copyWith(
                    color: q.value == selectedQuality ? p.bg : p.ink2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: MTSpace.xl),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(startLabel),
          ),
        ],
      ),
    );
  }
}
