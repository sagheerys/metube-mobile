import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/lists_data.dart';
import '../../data/saved_searches.dart';
import '../../router.dart';
import '../../shell/context_menu.dart';
import '../discover/discover_dialog.dart';
import '../settings/settings_place.dart';
import 'command_palette.dart';
import 'palette_model.dart';

/// Opens the palette with every command this window can run: adding a
/// link, each place, each saved list and each settings section. It opens
/// out of the search box at [from] when the title bar shows one.
Future<void> openPalette(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback onAdd,
  String initial = '',
  Rect? from,
}) {
  final l = context.mtl;
  final router = GoRouter.of(context);
  PaletteCommand go(String label, MTIconData icon, String to) =>
      PaletteCommand(label: label, icon: icon, run: () => router.go(to));
  final lists = ref.read(playlistsProvider).valueOrNull ?? const [];
  return showCommandPalette(
    context,
    initial: initial,
    from: from,
    commands: [
      PaletteCommand(label: l.addLinkFab, icon: MTIcons.addlink, run: onAdd),
      go(l.navLibrary, MTIcons.library, EmberRoutes.library),
      go(l.favorites, MTIcons.favorite, EmberRoutes.favorites),
      go(l.filterOffline, MTIcons.offline, EmberRoutes.offline),
      go(l.navPlaylists, MTIcons.queue, EmberRoutes.playlists),
      go(l.desktopChannels, MTIcons.subscriptions, EmberRoutes.channels),
      go(l.desktopStats, MTIcons.stats, EmberRoutes.stats),
      PaletteCommand(
        label: l.desktopDiscover,
        icon: MTIcons.info,
        run: () => unawaited(showDiscoverDialog(context)),
      ),
      for (final list in lists)
        go(
          l.desktopPaletteList(mtName(list.name)),
          MTIcons.queue,
          EmberRoutes.playlist(list.id),
        ),
      for (final pane in EmberSettingsPane.values)
        go(
          l.desktopPaletteSettings(paneTitle(l, pane)),
          MTIcons.settings,
          pane.route,
        ),
    ],
  );
}

enum _SavedAction { rename, delete }

/// A saved search's right-click menu: rename it, or delete it after
/// asking. Neither touches the library.
Future<void> savedSearchMenu(
  BuildContext context,
  WidgetRef ref,
  SavedSearch search,
  Offset at,
) async {
  final l = context.mtl;
  final action = await showEmberMenu(context, at, [
    EmberMenuEntry(_SavedAction.rename, MTIcons.tags, l.rename),
    EmberMenuEntry(_SavedAction.delete, MTIcons.trash, l.delete, danger: true),
  ]);
  if (!context.mounted || action == null) return;
  final searches = ref.read(savedSearchesProvider.notifier);
  switch (action) {
    case _SavedAction.rename:
      final name = await promptMTText(
        context,
        title: l.rename,
        confirmLabel: l.rename,
        initialValue: search.name,
        labelText: l.desktopSavedSearchName,
      );
      if (name != null) await searches.rename(search.id, name);
    case _SavedAction.delete:
      final sure = await showMTConfirm(
        context,
        title: l.delete,
        message: l.desktopSavedSearchDelete(mtName(search.name)),
        confirmLabel: l.delete,
        cancelLabel: l.cancel,
        destructive: true,
      );
      if (sure) await searches.remove(search.id);
  }
}

/// **Ctrl+K anywhere opens the palette**, in a text field too (it types
/// nothing there), but not while a dialog is open over the window.
class PaletteShortcut extends StatefulWidget {
  const PaletteShortcut({super.key, required this.onOpen, required this.child});

  final VoidCallback onOpen;
  final Widget child;

  @override
  State<PaletteShortcut> createState() => _PaletteShortcutState();
}

class _PaletteShortcutState extends State<PaletteShortcut> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.physicalKey != PhysicalKeyboardKey.keyK ||
        !HardwareKeyboard.instance.isControlPressed) {
      return false;
    }
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    widget.onOpen();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
