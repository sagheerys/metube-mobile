import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../di.dart';
import '../../shared/external_player.dart';
import '../../shared/membership.dart';
import '../library_models.dart';
import '../media_probe.dart';

/// Item details, opened from the actions sheet and from the reels player
/// alike.
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

  /// The local copy when there is one, otherwise the server's stream — the
  /// same order the library's own probe uses.
  Future<MediaQuality?> _readQuality(WidgetRef ref) async {
    const probe = MediaProbe();
    if (item.localPath case final String path) {
      return probe.quality(path: path);
    }
    final filename = item.serverFilename;
    if (filename == null) return null;
    final String url;
    try {
      url = ref.read(playbackResolverProvider).endpoint.buildUrl(filename);
    } on UnsafeFilenameException {
      // Rule 9: a URL is never built for an unsafe filename.
      return null;
    }
    return probe.quality(
      url: url,
      headers: ref.read(apiClientProvider)?.streamingHeaders ?? const {},
    );
  }

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
            // **Row labels** (full review 2026-09-02): "details" was the
            // label of the title row and "MB" the label of the size row, a
            // hard-coded string and a wrong meaning at once (rule 5).
            row(l10n.titleLabel, item.title),
            if (item.sizeBytes case final int bytes)
              row(l10n.fileSize, mtFormatSize(bytes)),
            // **What the file actually is** (asked 2026-09-25): the server
            // says "best" for everything; the header says 4K AV1.
            MTQualityRows(
              cacheKey: item.canonicalUrl,
              row: row,
              sizeBytes: item.sizeBytes,
              duration: item.duration,
              load: () => _readQuality(ref),
            ),
            if (item.timestamp != null)
              row(l10n.downloadDate, mtTimeAgo(context, item.timestamp!)),
            row(
              l10n.availability,
              [
                if (item.isOffline) l10n.availabilityOffline,
                if (item.onServer) l10n.availabilityServer,
              ].join(' + '),
            ),
            // **Where it belongs** (field report 2026-09-04): which
            // playlists it is in and which tags it carries. The information
            // was in the store and no screen displayed it.
            ...switch (ref
                .watch(membershipIndexProvider)
                .valueOrNull?[item.canonicalUrl]) {
              final ItemMembership m when !m.isEmpty => [
                if (m.playlists.isNotEmpty)
                  row(l10n.inPlaylists, m.playlists.join(l10n.listSeparator)),
                if (m.tags.isNotEmpty)
                  row(l10n.tags, m.tags.join(l10n.listSeparator)),
              ],
              _ => const <Widget>[],
            },
            const SizedBox(height: MTSpace.sm),
            // **Two actions, not a third button in reels** (decision
            // 2026-09-05): the rail already holds three buttons and a
            // fourth crowds them, and this sheet is opened from it by the
            // "details" button anyway.
            //
            // The external player appears **for a local copy only**: a
            // server URL is never handed to another app.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(item.canonicalUrl),
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
                if (item.localPath case final String path) ...[
                  const SizedBox(width: MTSpace.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final opened = await const ExternalPlayer().open(
                          path,
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
                      label: Text(
                        l10n.externalPlayerShort,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // The original URL, copied with one tap.
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: item.canonicalUrl));
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
