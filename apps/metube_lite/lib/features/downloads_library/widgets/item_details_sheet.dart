import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/external_player.dart';
import '../../shared/membership.dart';
import '../local_item.dart';

/// Item details, opened from the actions sheet and from the reels player
/// alike.
void showItemDetailsSheet(BuildContext context, LocalItem item) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _DetailsSheet(item: item),
  );
}

/// The details sheet: the name, size, date, platform and URL, each copied
/// with one tap.
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
            child: Text(label, style: text.bodySmall!.copyWith(color: p.ink3)),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MTSpace.xl,
          MTSpace.lg,
          MTSpace.xl,
          MTSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MTSectionHeader(title: l10n.details),
            const SizedBox(height: MTSpace.sm),
            // The same correction as Super: two wrong labels, one of them a
            // hard-coded string.
            row(l10n.titleLabel, item.title),
            row(
              l10n.fileSize,
              '${(item.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
            ),
            row(l10n.downloadDate, mtTimeAgo(context, item.modified)),
            row(l10n.platform, item.platform.label),
            // **Where it belongs** (field report 2026-09-04): which
            // playlists is this clip in? The information was in the store
            // and no screen displayed it.
            ...switch (ref
                .watch(membershipIndexProvider)
                .valueOrNull?[item.key]) {
              final ItemMembership m when m.playlists.isNotEmpty => [
                row(l10n.inPlaylists, m.playlists.join(l10n.listSeparator)),
              ],
              _ => const <Widget>[],
            },
            const SizedBox(height: MTSpace.sm),
            // **Two actions, not a third button in reels** (decision
            // 2026-09-05): the reels rail holds three buttons and a fourth
            // crowds them, and this sheet is opened from it by the
            // "details" button anyway.
            Row(
              children: [
                if (item.canonicalUrl case final String url)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(
                        l10n.openOriginalLink,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (item.canonicalUrl != null)
                  const SizedBox(width: MTSpace.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final opened = await const ExternalPlayer().open(
                        item.path,
                        audio: item.isAudio,
                      );
                      if (!opened && context.mounted) {
                        showMTSnack(
                          context,
                          l10n.noExternalPlayer,
                          type: MTSnackType.error,
                        );
                      }
                    },
                    icon: const Icon(Icons.open_with_rounded, size: 16),
                    // A short label: two buttons side by side leave no room
                    // for a long one on a phone (seen on the device).
                    label: Text(
                      l10n.externalPlayerShort,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            // The original URL, copied with one tap. Files migrated from
            // the old version have none, so their path is shown instead.
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: item.canonicalUrl ?? item.path),
                );
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
