import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/library_models.dart';
import 'playlist_dialogs.dart';
import 'playlists_providers.dart';

/// "Add to a playlist": a single item or a multi-selection (rule 6), with
/// playlist creation from here.
void showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  List<LibraryItem> items,
) {
  if (items.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _AddToPlaylistSheet(items: items),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.items});

  final List<LibraryItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final playlists = ref.watch(playlistsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(MTSpace.pagePad),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MTSectionHeader(
                title: l10n.addToPlaylist,
                trailing: l10n.queueItemsCount(items.length),
              ),
              const SizedBox(height: MTSpace.sm),
              Flexible(
                child: playlists.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Text(l10n.tryAgain),
                  data: (all) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final playlist in all) _tile(context, ref, playlist),
                      if (all.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(MTSpace.lg),
                          child: Text(
                            l10n.noPlaylistsMessage,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: MTSpace.sm),
              OutlinedButton.icon(
                onPressed: () => _createAndAdd(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.newPlaylistAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// **An "already added" mark** (field report 2026-09-03): the sheet
  /// showed every playlist alike, so there was no way to know where you had
  /// put the clip a moment ago short of opening each one. The store already
  /// prevented duplicates; what was missing was saying so.
  Widget _tile(BuildContext context, WidgetRef ref, SavedPlaylist playlist) {
    final l10n = context.mtl;
    final palette = MTThemeX.of(context).palette;
    final present = {for (final entry in playlist.items) entry.canonicalUrl};
    // The criterion: **all** of the selection is present. Otherwise the tap
    // still has something to add.
    final already = items.every(
      (item) => present.contains(toPlaylistEntry(item).canonicalUrl),
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        playlist.pinned ? Icons.push_pin_rounded : Icons.queue_music_rounded,
        color: palette.ink2,
      ),
      title: Text(playlist.name),
      subtitle: Text(
        already
            ? l10n.alreadyInPlaylist
            : l10n.queueItemsCount(playlist.items.length),
      ),
      trailing: already
          ? Icon(Icons.check_circle_rounded, color: palette.accent)
          : null,
      onTap: () => _add(context, ref, playlist, already: already),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    SavedPlaylist playlist, {
    bool already = false,
  }) async {
    Navigator.pop(context);
    await ref.read(playlistsStoreProvider).addItems(playlist.id, [
      for (final item in items) toPlaylistEntry(item),
    ]);
    ref.invalidate(playlistsProvider);
    ref.invalidate(playlistItemsProvider(playlist.id));
    if (context.mounted) {
      showMTSnack(
        context,
        already
            ? context.mtl.alreadyInPlaylist
            : (items.length == 1
                  ? context.mtl.videoAdded
                  : context.mtl.addedToPlaylistCount(items.length)),
        type: MTSnackType.success,
      );
    }
  }

  Future<void> _createAndAdd(BuildContext context, WidgetRef ref) async {
    final name = await promptPlaylistName(context);
    if (name == null || name.isEmpty) return;
    final playlist = await ref
        .read(playlistsStoreProvider)
        .create(name, items: [for (final item in items) toPlaylistEntry(item)]);
    ref.invalidate(playlistsProvider);
    if (context.mounted) {
      Navigator.pop(context);
      showMTSnack(
        context,
        context.mtl.playlistCreated,
        type: MTSnackType.success,
      );
    }
    // A new playlist can be opened straight from the tab; there is no
    // automatic navigation.
    ref.invalidate(playlistItemsProvider(playlist.id));
  }
}
