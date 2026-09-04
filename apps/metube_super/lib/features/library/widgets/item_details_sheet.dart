import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shared/membership.dart';
import '../library_models.dart';

/// تفاصيل عنصر — تُفتح من ورقة الإجراءات ومن مشغل الريلز معاً.
void showItemDetailsSheet(BuildContext context, LibraryItem item) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _DetailsSheet(item: item),
  );
}

class _DetailsSheet extends ConsumerWidget {
  const _DetailsSheet({required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final p = MTThemeX.of(context).palette;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: MTSpace.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(label,
                    style: text.bodySmall!.copyWith(color: p.ink3)),
              ),
              Expanded(child: Text(value, style: text.bodyMedium)),
            ],
          ),
        );

    final sizeMb = item.sizeBytes == null
        ? null
        : (item.sizeBytes! / (1024 * 1024)).toStringAsFixed(1);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.xl, MTSpace.lg, MTSpace.xl, MTSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MTSectionHeader(title: l10n.details),
            const SizedBox(height: MTSpace.sm),
            // **تسميات الصفوف** (فحص شامل 2026-09-02): كانت «التفاصيل»
            // عنواناً لصف العنوان و«MB» عنواناً لصف الحجم — نصّ
            // مثبت ومعنى خاطئ معاً (القاعدة 5).
            row(l10n.titleLabel, item.title),
            if (sizeMb != null) row(l10n.fileSize, '$sizeMb MB'),
            if (item.timestamp != null)
              row(l10n.downloadDate, mtTimeAgo(context, item.timestamp!)),
            row(l10n.availability, [
              if (item.isOffline) l10n.availabilityOffline,
              if (item.onServer) l10n.availabilityServer,
            ].join(' + ')),
            // **الانتماء** (بلاغ المالك 2026-09-04): في أي قوائم وتحت
            // أي وسوم. المعلومة كانت في المخزن ولا تعرضها أي شاشة.
            ...switch (ref
                .watch(membershipIndexProvider)
                .value?[item.canonicalUrl]) {
              final ItemMembership m when !m.isEmpty => [
                  if (m.playlists.isNotEmpty)
                    row(l10n.inPlaylists, m.playlists.join('، ')),
                  if (m.tags.isNotEmpty) row(l10n.tags, m.tags.join('، ')),
                ],
              _ => const <Widget>[],
            },
            const SizedBox(height: MTSpace.sm),
            // الرابط الأصلي — نسخ بلمسة (م-16).
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: item.canonicalUrl));
                if (context.mounted) {
                  showMTSnack(context, l10n.settingsSaved);
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(
                item.canonicalUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

