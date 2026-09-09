import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import 'playlists_providers.dart';

/// The naming dialog, used for creating, for renaming, and for saving a
/// playback session.
Future<String?> promptPlaylistName(
  BuildContext context, {
  String? initialName,
  String? title,
}) {
  final l10n = context.mtl;
  // The dialog owns the controller and disposes it; see
  // `mt_text_prompt.dart`.
  return promptMTText(
    context,
    title: title ?? l10n.createPlaylist,
    confirmLabel: initialName == null ? l10n.create : l10n.rename,
    initialValue: initialName,
    labelText: l10n.playlistName,
    hintText: l10n.playlistNameHint,
  );
}

Future<void> showCreatePlaylistDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final name = await promptPlaylistName(context);
  if (name == null || name.isEmpty) return;
  await ref.read(playlistsStoreProvider).create(name);
  ref.invalidate(playlistsProvider);
  if (context.mounted) {
    showMTSnack(
      context,
      context.mtl.playlistCreated,
      type: MTSnackType.success,
    );
  }
}

/// A long press on a playlist card (rule 7): pin, edit, delete.
void showPlaylistActionsSheet(
  BuildContext context,
  WidgetRef ref,
  SavedPlaylist playlist,
) {
  final l10n = context.mtl;
  final p = MTThemeX.of(context).palette;
  final store = ref.read(playlistsStoreProvider);

  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => SafeArea(
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
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              playlist.pinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              color: p.ink2,
            ),
            title: Text(
              playlist.pinned ? l10n.unpinPlaylist : l10n.pinPlaylist,
            ),
            onTap: () async {
              Navigator.pop(sheetContext);
              await store.setPinned(playlist.id, !playlist.pinned);
              ref.invalidate(playlistsProvider);
            },
          ),
          ListTile(
            leading: Icon(Icons.edit_rounded, color: p.ink2),
            title: Text(l10n.rename),
            onTap: () async {
              Navigator.pop(sheetContext);
              if (!context.mounted) return;
              final name = await promptPlaylistName(
                context,
                initialName: playlist.name,
                title: l10n.rename,
              );
              if (name == null || name.isEmpty) return;
              await store.rename(playlist.id, name);
              ref.invalidate(playlistsProvider);
            },
          ),
          // **Removing dead entries with one tap** (field report
          // 2026-09-04: "I deleted the files and they stayed in the
          // playlist"). Deleting from inside the app now prunes the
          // playlists automatically, and this cures what accumulated before
          // that, or what was deleted from outside the app.
          // `read` rather than `watch`: this is a function, not a `build`,
          // and `WidgetRef.watch` outside a build throws at runtime where
          // the analyser cannot catch it.
          if (ref.read(playlistViewProvider(playlist.id)).valueOrNull
              case final PlaylistView view when view.missing.isNotEmpty)
            ListTile(
              leading: Icon(Icons.playlist_remove_rounded, color: p.ink2),
              title: Text(l10n.removeUnavailable(view.missing.length)),
              onTap: () async {
                Navigator.pop(sheetContext);
                for (final key in view.missing) {
                  await store.removeItem(playlist.id, key);
                }
                ref.invalidate(playlistViewProvider(playlist.id));
                ref.invalidate(playlistItemsProvider(playlist.id));
                ref.invalidate(playlistsProvider);
              },
            ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: p.err),
            title: Text(
              l10n.delete,
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(color: p.err),
            ),
            onTap: () async {
              Navigator.pop(sheetContext);
              if (!context.mounted) return;
              final ok = await _confirmDelete(context, playlist.name);
              if (!ok) return;
              await store.delete(playlist.id);
              ref.invalidate(playlistsProvider);
              if (context.mounted) {
                showMTSnack(context, l10n.playlistDeleted);
              }
            },
          ),
          const SizedBox(height: MTSpace.md),
        ],
      ),
    ),
  );
}

Future<bool> _confirmDelete(BuildContext context, String name) async {
  final l10n = context.mtl;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(l10n.deletePlaylistConfirm(name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}
