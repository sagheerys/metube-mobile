import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../downloads_library/library_actions.dart';
import '../downloads_library/local_item.dart';
import '../playlists/add_to_playlist_sheet.dart';

/// **"Add to…": one place for every kind of belonging** (field report
/// 2026-09-04).
///
/// In reels the heart was a standalone button in the rail, and "add to a
/// playlist" had no entry point at all. One button gathers both and makes
/// the heart redundant, which is why it was removed from the rail.
///
/// **No tags in Lite**, deliberately: tags are a Super feature.
void showAddToSheet(BuildContext context, WidgetRef ref, LocalItem item) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    // The screen's context, not the sheet's: the later sheets open after
    // this
    // one closes.
    builder: (_) => _AddToSheet(item: item, host: context),
  );
}

class _AddToSheet extends ConsumerWidget {
  const _AddToSheet({required this.item, required this.host});

  final LocalItem item;
  final BuildContext host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MTSpace.xl,
              MTSpace.lg,
              MTSpace.xl,
              MTSpace.sm,
            ),
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              item.favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: item.favorite ? p.favorite : p.ink2,
            ),
            title: Text(
              item.favorite ? l10n.removeFromFavorites : l10n.addToFavorites,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            onTap: () async {
              Navigator.pop(context);
              final added = await ref
                  .read(libraryActionsProvider)
                  .toggleFavorite(item.key);
              if (!host.mounted) return;
              showMTSnack(
                host,
                added ? l10n.addedToFavorites : l10n.removedFromFavorites,
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.playlist_add_rounded, color: p.ink2),
            title: Text(
              l10n.addToPlaylist,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            onTap: () {
              Navigator.pop(context);
              showAddToPlaylistSheet(host, ref, [item]);
            },
          ),
          const SizedBox(height: MTSpace.md),
        ],
      ),
    );
  }
}
