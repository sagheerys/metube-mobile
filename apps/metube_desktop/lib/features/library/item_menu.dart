import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/folders_data.dart';
import '../../data/local_copies.dart';
import '../../shell/context_menu.dart';
import '../../shell/error_text.dart';
import '../clip/clip_actions.dart';
import '../clip/copy_pills.dart';
import '../clip/tags_dialog.dart';
import '../lists/list_dialogs.dart';
import 'clip_keys.dart';
import 'copy_file.dart';

enum ItemChoice {
  play,
  playNext,
  readingRoom,
  favorite,
  makeOffline,
  copyLink,
  copyFile,
  showInFolder,
  openWith,
  openOriginal,
  addToList,
  tags,
  download,
  removeLocalCopy,
  deleteFromServer,
  deleteLocal,
}

/// The right-click menu of a clip in the library, by its state. Playing
/// comes first, each with the key that does it on a chosen clip; then the
/// rest **in the order of the phone's actions sheet** so nothing has to be
/// learned twice: the phone's share is the link copied, its external
/// player the file shown in Explorer. Deleting comes last, apart and in
/// the error colour, behind a confirmation.
List<EmberMenuEntry<ItemChoice>> itemMenuEntries(
  MTLocalizations l,
  LibraryItem item, {
  required bool hasFile,
}) {
  final source = copySourceOf(item);
  return [
    EmberMenuEntry(
      ItemChoice.play,
      MTIcons.play,
      l.play,
      shortcut: ClipKeys.play,
    ),
    EmberMenuEntry(
      ItemChoice.playNext,
      MTIcons.next,
      l.desktopPlayNext,
      shortcut: ClipKeys.playNext,
    ),
    EmberMenuEntry(
      ItemChoice.readingRoom,
      MTIcons.reading,
      l.desktopReadingRoom,
      shortcut: ClipKeys.reading,
    ),
    EmberMenuEntry(
      ItemChoice.favorite,
      item.favorite ? MTIcons.favoriteOn : MTIcons.favorite,
      item.favorite ? l.removeFromFavorites : l.addToFavorites,
      shortcut: ClipKeys.favorite,
    ),
    const EmberMenuEntry.divider(),
    if (source != null && !item.isOffline)
      EmberMenuEntry(ItemChoice.makeOffline, MTIcons.offline, l.makeOffline),
    EmberMenuEntry(
      ItemChoice.copyLink,
      MTIcons.link,
      l.desktopCopyLink,
      shortcut: ClipKeys.copyLink,
    ),
    if (hasFile || source != null)
      EmberMenuEntry(
        ItemChoice.copyFile,
        MTIcons.copy,
        l.desktopCopyFile,
        shortcut: ClipKeys.copyFile,
      ),
    if (hasFile) ...[
      EmberMenuEntry(
        ItemChoice.showInFolder,
        MTIcons.folder,
        l.desktopShowInFolder,
      ),
      // The phone's external player: a file on this computer only, never
      // a server address (see DesktopFolders.openWith).
      EmberMenuEntry(ItemChoice.openWith, MTIcons.playback, l.desktopOpenWith),
    ],
    EmberMenuEntry(
      ItemChoice.openOriginal,
      MTIcons.external,
      l.openOriginalLink,
    ),
    EmberMenuEntry(ItemChoice.addToList, MTIcons.queue, l.addToPlaylist),
    EmberMenuEntry(ItemChoice.tags, MTIcons.tags, l.tags),
    if (source != null)
      EmberMenuEntry(ItemChoice.download, MTIcons.saveTo, l.desktopDownloadTo),
    if (item.isOffline && item.onServer)
      EmberMenuEntry(
        ItemChoice.removeLocalCopy,
        MTIcons.offline,
        l.removeLocalCopy,
      ),
    if (item.onServer || item.isOffline) const EmberMenuEntry.divider(),
    if (item.onServer)
      EmberMenuEntry(
        ItemChoice.deleteFromServer,
        MTIcons.trash,
        l.deleteFromServer,
        danger: true,
      )
    else if (item.isOffline)
      EmberMenuEntry(
        ItemChoice.deleteLocal,
        MTIcons.trash,
        l.deleteVideo,
        danger: true,
      ),
  ];
}

/// [onPlay] plays as a double click on the clip would: the list on screen
/// from it.
Future<void> showItemMenu(
  BuildContext context,
  WidgetRef ref,
  Offset globalPosition,
  LibraryItem item, {
  required VoidCallback onPlay,
}) async {
  final l = context.mtl;
  final file = item.localPath;
  final hasFile = file != null && File(file).existsSync();
  final choice = await showEmberMenu(
    context,
    globalPosition,
    itemMenuEntries(l, item, hasFile: hasFile),
  );
  if (choice == null || !context.mounted) return;
  final source = copySourceOf(item);
  switch (choice) {
    case ItemChoice.play:
      onPlay();
    case ItemChoice.playNext:
      await playNextOf(context, ref, item);
    case ItemChoice.readingRoom:
      openReadingOf(context, item.canonicalUrl);
    case ItemChoice.favorite:
      await ref.read(clipActionsProvider).toggleFavorite(item.canonicalUrl);
    case ItemChoice.makeOffline:
      if (source != null) await makeOfflineCopy(context, ref, source);
    case ItemChoice.copyLink:
      await copyLinkOf(context, item.canonicalUrl);
    case ItemChoice.copyFile:
      await copyFileOf(context, item);
    case ItemChoice.showInFolder:
      if (file != null) await ref.read(desktopFoldersProvider).reveal(file);
    case ItemChoice.openWith:
      if (file != null) await ref.read(desktopFoldersProvider).openWith(file);
    case ItemChoice.openOriginal:
      await ref.read(clipActionsProvider).openOriginal(item.canonicalUrl);
    case ItemChoice.addToList:
      await showAddToPlaylistDialog(context, toPlaylistItem(item));
    case ItemChoice.tags:
      await showTagsDialog(context, item.canonicalUrl);
    case ItemChoice.download:
      if (source != null) await downloadCopy(context, ref, source);
    case ItemChoice.removeLocalCopy:
      await removeOfflineCopy(context, ref, item);
    case ItemChoice.deleteFromServer:
      final sure = await _sure(
        context,
        l.deleteFromServer,
        l.deleteFromServerConfirm,
      );
      if (!sure) return;
      try {
        await ref.read(clipActionsProvider).deleteFromServer(item.canonicalUrl);
      } on Object catch (e) {
        if (context.mounted) {
          showMTNotice(
            context,
            message: errorText(l, e),
            kind: MTNoticeKind.failed,
          );
        }
        return;
      }
      if (context.mounted) {
        showMTNotice(context, message: l.deletedFromServer);
      }
    case ItemChoice.deleteLocal:
      final sure = await _sure(
        context,
        l.deleteVideo,
        l.deleteVideoConfirm(mtName(item.title)),
      );
      if (!sure || !context.mounted) return;
      await ref.read(localCopiesProvider.notifier).removeLocalCopy(item);
      if (context.mounted) {
        showMTNotice(context, message: l.deletedTitle(mtName(item.title)));
      }
  }
}

Future<bool> _sure(BuildContext context, String title, String message) {
  final l = context.mtl;
  return showMTConfirm(
    context,
    title: title,
    message: message,
    confirmLabel: l.delete,
    cancelLabel: l.cancel,
    destructive: true,
  );
}
