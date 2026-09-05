import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/external_player.dart';
import '../../shared/membership.dart';
import '../local_item.dart';

/// تفاصيل عنصر — تُفتح من ورقة الإجراءات ومن مشغل الريلز معاً.
void showItemDetailsSheet(BuildContext context, LocalItem item) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _DetailsSheet(item: item),
  );
}

/// ورقة التفاصيل (م-16): الاسم والحجم والتاريخ والمنصة والرابط بنسخ بلمسة.
class _DetailsSheet extends ConsumerWidget {
  const _DetailsSheet({required this.item});

  final LocalItem item;

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
                child:
                    Text(label, style: text.bodySmall!.copyWith(color: p.ink3)),
              ),
              Expanded(child: Text(value, style: text.bodyMedium)),
            ],
          ),
        );

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
            // نفس تصحيح Super: تسميتان خاطئتان إحداهما نص مثبت.
            row(l10n.titleLabel, item.title),
            row(l10n.fileSize,
                '${(item.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'),
            row(l10n.downloadDate, mtTimeAgo(context, item.modified)),
            row(l10n.platform, item.platform.label),
            // **الانتماء** (بلاغ المالك 2026-09-04): في أي قوائم هذا
            // المقطع؟ المعلومة كانت في المخزن ولا تعرضها أي شاشة.
            ...switch (ref
                .watch(membershipIndexProvider)
                .valueOrNull?[item.key]) {
              final ItemMembership m when m.playlists.isNotEmpty => [
                  row(l10n.inPlaylists, m.playlists.join('، ')),
                ],
              _ => const <Widget>[],
            },
            const SizedBox(height: MTSpace.sm),
            // **فعلان لا زر ثالث في الريلز** (قرار المالك 2026-09-05):
            // شريط الريلز فيه ثلاثة أزرار وزيادةُ رابعٍ تزاحمه، وهذه
            // الورقة تُفتح منه بزر «التفاصيل» أصلاً.
            Row(
              children: [
                if (item.canonicalUrl case final String url)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(l10n.openOriginalLink,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                if (item.canonicalUrl != null)
                  const SizedBox(width: MTSpace.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final opened = await const ExternalPlayer()
                          .open(item.path, audio: item.isAudio);
                      if (!opened && context.mounted) {
                        showMTSnack(context, l10n.noExternalPlayer,
                            type: MTSnackType.error);
                      }
                    },
                    icon: const Icon(Icons.open_with_rounded, size: 16),
                    // نصّ قصير: زرّان جنباً إلى جنب لا يتسع لهما
                    // النصّ الطويل على هاتف (رئي على الجهاز).
                    label: Text(l10n.externalPlayerShort,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            // الرابط الأصلي — نسخ بلمسة (م-16). الملفات المهاجرة من
            // النسخة القديمة لا رابط لها فيُعرض مسارها بدله.
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: item.canonicalUrl ?? item.path));
                if (context.mounted) {
                  showMTSnack(context, l10n.copiedToClipboard);
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(
                item.canonicalUrl ?? item.filename,
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

