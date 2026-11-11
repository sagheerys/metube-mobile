import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../data/backup_data.dart';
import '../data/covers/covers_data.dart';
import '../data/shapes/shapes_data.dart';
import '../data/library_data.dart';
import '../data/library_watch.dart';
import '../data/sync_runner.dart';
import '../data/taskbar_data.dart';
import '../data/lists_data.dart';
import '../data/saved_searches.dart';
import '../di.dart';
import '../features/add/add_dialog.dart';
import '../features/add/add_entry.dart';
import '../features/add/outside_links.dart';
import '../features/clip/clip_state.dart';
import '../features/downloads/downloads_button.dart';
import '../features/folders/folder_tree.dart';
import '../features/listening/listening_layer.dart';
import '../features/listening/listening_room.dart';
import '../features/library/library_state.dart';
import '../features/notices/copied_links_wiring.dart';
import '../features/notices/notices_wiring.dart';
import '../features/palette/palette_entry.dart';
import '../features/palette/palette_grow.dart';
import '../features/settings/backup_actions.dart';
import '../features/discover/discover_once.dart';
import '../router.dart';
import 'content_bar.dart';
import 'focus_regions.dart';
import 'keyboard.dart';
import 'mini_window.dart';
import 'nav_history.dart';
import 'panel_reveal.dart';
import 'panel/transcript_view.dart';
import 'player_bar.dart';
import 'right_panel.dart';
import 'shell_layout.dart';
import 'shell_metrics.dart';
import 'shell_state.dart';
import 'sidebar.dart';
import 'sidebar_items.dart';
import 'title_bar.dart';

/// The window's frame around every place: title bar, sidebar, content,
/// side panel and the player bar. Built once for the life of the app (it
/// is the router's shell), so nothing it holds restarts on navigation.
class EmberShell extends ConsumerStatefulWidget {
  const EmberShell({super.key, required this.location, required this.child});

  final Uri location;
  final Widget child;

  @override
  ConsumerState<EmberShell> createState() => _EmberShellState();
}

/// The id of the saved list whose page [location] is, if it is one.
String? _openList(Uri location) => switch (location.pathSegments) {
  ['playlists', final id] => id,
  _ => null,
};

class _EmberShellState extends ConsumerState<EmberShell> {
  NavHistory? _history;
  PanelTab _tab = PanelTab.transcript;

  /// The panel as a layer over the content, in a narrow window only. Not
  /// saved: a layer left open would cover the content on the next start.
  bool _overlayOpen = false;

  @override
  void initState() {
    super.initState();
    // The setup, Discover or what is new: one at most (see there).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(startupOffers(context, ref));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _history ??= NavHistory.of(GoRouter.of(context));
  }

  @override
  void dispose() {
    _history?.dispose();
    super.dispose();
  }

  void _togglePanel(ShellArrangement arranged, ShellLayout layout) {
    if (arranged.panelBeside) {
      ref
          .read(shellLayoutProvider.notifier)
          .setPanelHidden(!layout.panelHidden);
    } else {
      setState(() => _overlayOpen = !_overlayOpen);
    }
  }

  void _showTab(PanelTab tab, ShellArrangement arranged) {
    setState(() {
      _tab = tab;
      if (!arranged.panelBeside) _overlayOpen = true;
    });
    if (arranged.panelBeside) {
      ref.read(shellLayoutProvider.notifier).setPanelHidden(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final layout = ref.watch(shellLayoutProvider);
    final player = ref.watch(playerProvider);
    final controls = ref.watch(windowControlsProvider);
    final router = GoRouter.of(context);
    ref.watch(playbackWiringProvider);
    ref.watch(sessionRestoreProvider);
    ref.watch(coverEnrichmentProvider);
    ref.watch(shapeEnrichmentProvider);
    ref.watch(startupBackupProvider);
    ref.watch(syncRunnerProvider);
    ref.watch(libraryWatchProvider);
    ref.watch(taskbarDownloadsWiringProvider);

    // Theater widens a clip's picture over the side panel's column too.
    final theater =
        ref.watch(theaterProvider) &&
        placeOf(widget.location) == EmberPlace.item;
    final audioOnly = ref.watch(audioOnlyProvider);
    final listening = ref.watch(listeningProvider);
    EmberPlayerBar playerBar(ShellArrangement? arranged) => EmberPlayerBar(
      player: player,
      audioOnly: audioOnly,
      // Full screen is the room, while sound plays.
      listening: listening || arranged == null,
      onListen: () => toggleListening(ref),
      onShowQueue: () => arranged == null
          ? controls.setFullScreen(false)
          : _showTab(PanelTab.upNext, arranged),
      onOpen: (url) => router.go(EmberRoutes.item(url)),
      onMini: _toggleMini,
    );

    final drop = ref.watch(linkDropProvider);
    // A Scaffold underneath, so notices (`showMTNotice`) have somewhere to
    // appear, above the player bar.
    final scaffold = Scaffold(
      backgroundColor: p.bg,
      body: ValueListenableBuilder<bool>(
        valueListenable: controls.fullScreen,
        builder: (context, full, _) => full
            // The whole screen for the picture, with its controls over it,
            // or the listening room for sound, with the player bar.
            ? ListeningLayer(
                full: true,
                onClose: () => toggleListening(ref),
                bar: playerBar(null),
                child: widget.child,
              )
            : _framed(context, layout, theater, playerBar),
      ),
    );
    // Links reach the add dialog from the button, Ctrl+V anywhere but a
    // text field, a drop on the window (where a phone's backup goes to the
    // import instead), and from outside: a `metube://` link or a link
    // copied elsewhere, when the user asked to be offered those.
    return PaletteShortcut(
      onOpen: _openPalette,
      child: EmberKeyboard(
        // In the reading room, Ctrl+F finds in its text.
        onSearch: () => (findHere(ref) ?? _openPalette)(),
        onMini: _toggleMini,
        inShortsLane: () =>
            placeOf(widget.location) == EmberPlace.item &&
            (player.state.current?.isShortForm ?? false),
        child: NoticesWiring(
          child: OutsideLinks(
            child: CopiedLinksWiring(
              child: AddShortcut(
                onLinks: _openAdd,
                // The small card in place of the frame, the wirings above it
                // still listening.
                child: drop(
                  ValueListenableBuilder<bool>(
                    valueListenable: controls.mini,
                    builder: (context, mini, _) => mini
                        ? EmberMiniWindow(
                            player: player,
                            controls: controls,
                            onRestore: _toggleMini,
                          )
                        : scaffold,
                  ),
                  _onDrop,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The palette is the search: Ctrl+K, the search box and the sidebar's
  /// Search all open it, and a saved search opens it on its query.
  void _openPalette([String initial = '']) => unawaited(
    openPalette(
      context,
      ref,
      onAdd: () => unawaited(_addFromButton()),
      initial: initial,
      from: paletteAnchor(_searchBox, context),
    ),
  );

  /// The title bar's search box, which the palette opens out of.
  final _searchBox = GlobalKey();

  void _toggleMini() => toggleMiniWindow(ref, GoRouter.of(context));

  void _openAdd([String text = '']) =>
      unawaited(openAddDialog(context, text: text));

  /// A dropped phone backup or transcripts file is imported; anything
  /// else is links for the add dialog.
  void _onDrop(String text) => isBackupText(text)
      ? unawaited(importFromPhone(context, ref, text))
      : _openAdd(text);

  /// The button offers what the clipboard holds, as the phone's does.
  Future<void> _addFromButton() async {
    final text = await clipboardLinks();
    if (mounted) _openAdd(text);
  }

  Widget _framed(
    BuildContext context,
    ShellLayout layout,
    bool theater,
    EmberPlayerBar Function(ShellArrangement) playerBar,
  ) {
    final player = ref.read(playerProvider);
    final controls = ref.read(windowControlsProvider);
    final router = GoRouter.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final arranged = arrangeShell(box.maxWidth, layout);
        final place = placeOf(widget.location);
        final folder = ref.watch(libraryViewProvider).folder;
        final panelShown =
            !theater &&
            (arranged.panelBeside ? !layout.panelHidden : _overlayOpen);
        final panel = inRegion(
          EmberRegion.panel,
          StreamBuilder<MTPlayerState>(
            stream: player.states,
            initialData: player.state,
            builder: (context, snap) => EmberRightPanel(
              tab: _tab,
              onTab: (tab) => setState(() => _tab = tab),
              state: snap.data ?? player.state,
              player: player,
            ),
          ),
        );
        return regionsInOrder(
          Column(
            children: [
              EmberTitleBar(
                controls: controls,
                startWidth: arranged.sidebarWidth,
                sidebarToggle: arranged.canWidenSidebar
                    ? inRegion(
                        EmberRegion.sidebar,
                        SidebarToggle(
                          narrow: arranged.sidebarNarrow,
                          onTap: () => ref
                              .read(shellLayoutProvider.notifier)
                              .setSidebarNarrow(!layout.sidebarNarrow),
                        ),
                      )
                    : null,
                tools: inRegion(
                  EmberRegion.contentBar,
                  EmberContentBar(
                    history: _history!,
                    onSearch: _openPalette,
                    searchKey: _searchBox,
                    panelShown: panelShown,
                    onTogglePanel: () => _togglePanel(arranged, layout),
                    downloads: const DownloadsButton(),
                  ),
                ),
              ),
              Expanded(
                child: ListeningLayer(
                  full: false,
                  onClose: () => toggleListening(ref),
                  bar: inRegion(EmberRegion.playerBar, playerBar(arranged)),
                  child: Row(
                    children: [
                      inRegion(
                        EmberRegion.sidebar,
                        EmberSidebar(
                          narrow: arranged.sidebarNarrow,
                          current: place,
                          pinned: ref.watch(pinnedPlaylistsProvider),
                          currentList: _openList(widget.location),
                          folders: sidebarFolders(
                            ref.watch(libraryItemsProvider).valueOrNull ??
                                const [],
                            folder,
                          ),
                          currentFolder: place == EmberPlace.library
                              ? folder
                              : null,
                          onFolder: (path) {
                            // The chosen folder again goes up a level.
                            final view = ref.read(libraryViewProvider.notifier);
                            view.setFolder(
                              path == folder && place == EmberPlace.library
                                  ? parentFolder(path)
                                  : path,
                            );
                            router.go(EmberRoutes.library);
                          },
                          onGo: (to) => to == EmberRoutes.search
                              ? _openPalette()
                              : router.go(to),
                          searches:
                              ref.watch(savedSearchesProvider).valueOrNull ??
                              const [],
                          onSavedSearch: (search) => _openPalette(search.query),
                          onSavedSearchMenu: (search, at) => unawaited(
                            savedSearchMenu(context, ref, search, at),
                          ),
                          onAdd: () => unawaited(_addFromButton()),
                        ),
                      ),
                      // The layer opens over the content only, under the
                      // title bar with its toggle.
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: inRegion(
                                EmberRegion.content,
                                widget.child,
                                focus: ref.watch(contentFocusProvider),
                              ),
                            ),
                            if (!arranged.panelBeside && !theater)
                              ...overlayPanel(
                                open: _overlayOpen,
                                onClose: () =>
                                    setState(() => _overlayOpen = false),
                                panel: panel,
                              ),
                          ],
                        ),
                      ),
                      if (arranged.panelBeside)
                        PanelReveal(shown: panelShown, child: panel),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
