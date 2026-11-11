import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/library_data.dart';
import '../../data/lists_data.dart';
import '../../features/clip/clip_facts.dart';
import '../../features/library/platform_label.dart';
import '../video_surface.dart';

/// What is known about the playing clip, with its link one click from the
/// clipboard (a phone hides this in a sheet; the panel has the room).
///
/// **The phone's details and more**: the size, the video and the sound as
/// the file really is (the server records "best", not what came), the
/// date it arrived, where it is kept, and the lists and tags it is in.
class DetailsView extends ConsumerWidget {
  const DetailsView({super.key, required this.item});

  final PlaylistItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final url = item.canonicalUrl;
    final entry = (ref.watch(libraryItemsProvider).valueOrNull ?? const [])
        .where((i) => i.canonicalUrl == url)
        .firstOrNull;
    final lists = <String>[
      for (final list
          in ref.watch(playlistsProvider).valueOrNull ??
              const <SavedPlaylist>[])
        if (list.items.any((e) => e.canonicalUrl == url)) list.name,
    ];
    final tags = [
      for (final tag in entry?.tags ?? const <String>[])
        if (tag != MTConstants.favoritesSystemTag) tag,
    ];
    final folder = switch (item.serverFilename) {
      final name? => ServerPath.folderOf(name),
      null => '',
    };
    final size = entry?.sizeBytes;
    final format = entry == null ? null : fileFormatOf(entry);
    final when = entry?.timestamp;
    Widget row(String label, String value) => _Row(label: label, value: value);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selectable, to copy it (owner's request 2026-11-11).
          _Row(label: l.titleLabel, value: item.title, selectable: true),
          if (item.uploader case final who?) row(l.desktopChannel, who),
          row(l.platform, platformLabel(l, MediaPlatform.detect(url))),
          if (item.duration case final length?)
            row(l.columnLength, mtLtrRun(mtFormatDuration(length))),
          if (size != null) row(l.fileSize, mtFormatSize(size)),
          if (format != null) row(l.format, format),
          MTQualityRows(
            key: ValueKey(url),
            cacheKey: url,
            row: row,
            sizeBytes: size,
            duration: item.duration,
            load: ref.read(videoSurfaceProvider).quality,
          ),
          if (when != null) row(l.downloadDate, mtTimeAgo(context, when)),
          if (entry != null) row(l.availability, _availability(l, entry)),
          if (folder.isNotEmpty) row(l.folder, mtName(folder)),
          if (lists.isNotEmpty)
            row(l.inPlaylists, lists.map(mtName).join(l.listSeparator)),
          if (tags.isNotEmpty) row(l.tags, tags.join(l.listSeparator)),
          // Where it plays from only when the availability above is missing:
          // beside it, the two read as the same line twice.
          if (entry == null)
            row(
              l.source,
              item.localPath != null
                  ? l.playingFromDevice
                  : l.streamingFromServer,
            ),
          const SizedBox(height: MTSpace.md),
          _LinkRow(url: url),
        ],
      ),
    );
  }

  static String _availability(MTLocalizations l, LibraryItem entry) => [
    if (entry.isOffline) l.availabilityOffline,
    if (entry.onServer) l.availabilityServer,
  ].join(' + ');
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final line = Text(
      value,
      textDirection: mtTextDirectionOf(value, Directionality.of(context)),
      style: text.bodySmall?.copyWith(color: p.ink),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: MTSpace.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: p.line,
            width: MTThemeX.of(context).hairline,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: MTSpace.xxl * 3,
            child: Text(label, style: text.labelSmall?.copyWith(color: p.ink3)),
          ),
          Expanded(child: selectable ? MTSelectable(child: line) : line),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // An address reads left to right in any language.
        Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText(
            url,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: p.ink2),
          ),
        ),
        const SizedBox(height: MTSpace.xs),
        MTLinkButton(
          label: l.desktopCopyLink,
          icon: MTIcons.copy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (!context.mounted) return;
            showMTNotice(context, message: l.desktopLinkCopied);
          },
        ),
      ],
    );
  }
}
