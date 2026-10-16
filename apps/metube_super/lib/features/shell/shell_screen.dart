import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../home/add_flow.dart';
import '../home/app_shortcuts.dart';
import '../home/download_watcher.dart';
import '../home/network_gate.dart';
import '../home/quick_download.dart';
import '../home/reception.dart';
import '../library/library_enricher.dart';
import '../library/library_models.dart' show MediaTypeFilter;
import '../library/library_providers.dart'
    show completionGlowProvider, libraryViewProvider;
import '../library/quality_backfill.dart';
import '../player/playback_providers.dart';
import '../settings/resume_refresh.dart';
import '../update/update_sheet.dart';
import '../subscriptions/arrival_watcher.dart';
import '../transcripts/sidecar_backfill.dart';
import '../transcripts/transcript_openers.dart';
import '../transcripts/transcripts_state.dart';
import '../update/update_state.dart';
import '../update/whats_new_prompt.dart';
import '../shared/notification_permission.dart';
import 'share_landing.dart';

/// The shell: three bottom destinations plus the floating layer holding
/// the smart add button, which appears in the library and the playlists
/// and hides in settings.
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WidgetsBindingObserver {
  ShareReceiver? _shareReceiver;

  /// **It is never shown while anything is open above the shell**: the
  /// share sheet or the restore dialog may be on screen the moment the
  /// check finishes, and stacking a sheet over a sheet swallows the user's
  /// touch and hides what they were doing.
  ///
  /// Once per run: the "updates" row in settings stays as a witness in the
  /// accent colour for anyone who closed the sheet.
  bool _updatePrompted = false;

  /// "What's new" comes first, and an update offer waits for the next
  /// resume rather than stacking on top of it.
  bool _whatsNewDone = false;

  Future<void> _maybeShowUpdate() async {
    if (!_whatsNewDone) {
      final outcome = await maybeShowWhatsNew(context, ref);
      if (outcome != WhatsNewOutcome.later) _whatsNewDone = true;
      if (outcome != WhatsNewOutcome.nothing || !mounted) return;
    }
    if (_updatePrompted) return;
    await ref.read(updateControllerProvider.notifier).checkSilently();
    if (!mounted || _updatePrompted) return;
    if (ref.read(updateControllerProvider).phase != UpdatePhase.available) {
      return;
    }
    if (MTRouteDepth.depth.value != 0) return;
    _updatePrompted = true;
    unawaited(ref.read(loggerProvider).log('update sheet shown', tag: 'ui'));
    showUpdateSheet(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shareReceiver = ShareReceiver(
      onUrls: (urls) => unawaited(_onSharedUrls(urls)),
      onLog: (message) =>
          unawaited(ref.read(loggerProvider).log(message, tag: 'share')),
    );
    _shareReceiver!.start();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(clipboardRefresherProvider)();
      // Revives the saved audio session, without autoplaying, after
      // playbackWiringProvider has set the current server URL.
      ref.read(playbackWiringProvider);
      ref.read(audioHandlerProvider).restoreSession();
      // Download notifications (decision 2026-09-06); their channels are
      // separate from the media channel above.
      const NotificationPermission().request();
      await initDownloadNotifications(ref);
      if (mounted) unawaited(_handleShortcut());
      if (mounted) unawaited(_maybeShowUpdate());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(clipboardRefresherProvider)();
      // A shortcut arrives as a new intent on a running app, not as a fresh
      // start.
      unawaited(_handleShortcut());
      unawaited(_maybeShowUpdate());
    }
  }

  /// Executing a launcher shortcut. **The clipboard is read now rather than
  /// from saved state**: the user copied the link and pressed the icon
  /// immediately, and the `clipboardUrlProvider` snapshot may predate the
  /// copy by seconds.
  Future<void> _handleShortcut() async {
    final shortcut = await const AppShortcuts().consume();
    if (shortcut == null || !mounted) return;
    switch (shortcut) {
      case AppShortcut.paste:
        await ref.read(clipboardRefresherProvider)();
        if (!mounted) return;
        final url = ref.read(clipboardUrlProvider);
        await landOnLibrary(widget.navigationShell);
        if (!mounted) return;
        if (url == null) {
          openAddSheet(context, ref);
        } else if (startQuickDownload(context, ref, url)) {
          ref.read(clipboardUrlProvider.notifier).state = null;
        } else {
          openAddSheet(context, ref, initialUrl: url);
        }
      case AppShortcut.shorts:
        widget.navigationShell.goBranch(0);
        ref.read(libraryViewProvider.notifier).setType(MediaTypeFilter.shorts);
      case AppShortcut.audio:
        widget.navigationShell.goBranch(0);
        ref.read(libraryViewProvider.notifier).setType(MediaTypeFilter.audio);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareReceiver?.dispose();
    super.dispose();
  }

  /// An external share opens `/` and starts rule 2 (several links are
  /// submitted one after another).
  Future<void> _onSharedUrls(List<String> shared) async {
    if (!mounted || shared.isEmpty) return;
    // Each step is logged, without the link: a share that showed nothing
    // can then be traced to where it stopped.
    final logger = ref.read(loggerProvider);
    void note(String step) => unawaited(logger.log(step, tag: 'share'));
    final started = DateTime.now();
    // **The decision is made on the final URL, not the shared one** (field
    // report 2026-09-08): SoundCloud's share button gives
    // `on.soundcloud.com/…` with no `/sets/`, so an album counted as a
    // single clip and the server expanded it into twenty with no selection
    // screen. A link that is not short costs no wait.
    final resolver = ref.read(shortLinkResolverProvider);
    final urls = [
      for (final url in shared) await resolver.resolveForRouting(url),
    ];
    note(
      'share checked in ${DateTime.now().difference(started).inMilliseconds}ms',
    );
    if (!mounted) return note('share dropped: the screen is gone');
    await landOnLibrary(widget.navigationShell);
    if (!mounted) return note('share dropped: the screen is gone');
    if (urls.length == 1) {
      if (_isPurePlaylistLink(urls.first)) {
        note('share to the playlist screen');
        GoRouter.of(context).push('/batch', extra: urls.first);
        return;
      }
      // "Quick download" makes the default quality an effective setting: a
      // shared link downloads immediately with no sheet, and the snack bar
      // offers an undo. The gate lives inside `startQuickDownload` itself,
      // so it is not repeated here.
      if (startQuickDownload(context, ref, urls.first)) {
        return note('share downloaded at once');
      }
      note('share to the add sheet');
      openAddSheet(context, ref, initialUrl: urls.first);
      return;
    }
    final engine = ref.read(downloadEngineProvider);
    if (engine == null) return note('share dropped: no server');
    note('share of ${urls.length} links');
    final quality = ref.read(settingsProvider).quality;
    for (final url in urls) {
      if (PlaylistDetector.isPlaylist(url)) {
        GoRouter.of(context).push('/batch', extra: url);
      } else {
        engine.submit(url, quality, isBatchMember: true);
      }
    }
    showMTSnack(
      context,
      context.mtl.downloadStarted,
      type: MTSnackType.success,
    );
  }

  /// A playlist **in its own right**, not a video inside a playlist.
  static bool _isPurePlaylistLink(String url) =>
      PlaylistDetector.isPlaylist(url) && UrlKit.youtubeVideoId(url) == null;

  /// A link waiting in the clipboard is acted on directly when the button
  /// is pressed.
  void _onFabPressed() {
    final clipboardUrl = ref.read(clipboardUrlProvider);
    if (clipboardUrl != null) {
      if (startQuickDownload(context, ref, clipboardUrl)) {
        ref.read(clipboardUrlProvider.notifier).state = null;
        return;
      }
      openAddSheet(context, ref, initialUrl: clipboardUrl);
      return;
    }
    openAddSheet(context, ref);
  }

  /// The clipboard bar: **it folds away and does not return** for the same
  /// link during this session.
  void _dismissClipboard() {
    _dismissedClipboardUrl = ref.read(clipboardUrlProvider);
    setState(() {});
  }

  String? _dismissedClipboardUrl;

  /// The player panel folded away by hand, for this run. The mini player
  /// stands in for it until it is unfolded.
  bool _panelFolded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final branch = widget.navigationShell.currentIndex;
    final clipboardUrl = ref.watch(clipboardUrlProvider);

    // Kept alive so it drives the download notifications.
    ref.watch(playbackWiringProvider);
    // Returning to the app asks the server again; the card is not truthful
    // without this.
    ref.watch(libraryEnrichmentProvider);
    // Stores each item's quality ahead of time, after the enricher has
    // shown its file is readable.
    ref.watch(qualityBackfillRunProvider);
    // Reads the subtitle files a server writes beside its clips, for the
    // clips that arrived without this app's own transcript fetch.
    ref.watch(sidecarBackfillRunProvider);
    // The completed item's highlight, watched from the shell so it never
    // misses a completion that happened while the user was on another
    // screen.
    ref.watch(completionGlowProvider);
    // Listens for the network returning and retries what failed because of
    // it.
    ref.watch(autoRetryProvider);
    ref.watch(batchDropWatcherProvider);
    // Kept alive so it drives the download notifications.
    ref.watch(downloadWatcherProvider);
    // The other half of that: what the server fetched on its own, which no
    // task in this app ever represented (a subscription arrival).
    ref.watch(arrivalWatcherProvider);
    // Returning to the app asks the server again; the card is not truthful
    // without this.
    ref.watch(resumeRefreshProvider);

    final handler = ref.watch(audioHandlerProvider);
    // The transcript tab beside the player follows the index as it loads.
    ref.watch(transcriptIndexProvider);
    ref.watch(transcriptsRevisionProvider);
    final roomForPanel = MTAdaptiveScaffold.hasEndPane(context);
    return StreamBuilder(
      stream: handler.mediaItem,
      builder: (context, playing) {
        // **The player panel** takes the mini player's place beside the
        // content on a tablet held sideways; settings has neither.
        final panel =
            branch != 2 &&
            playing.data != null &&
            !_panelFolded &&
            roomForPanel;
        return MTAdaptiveScaffold(
          endPane: panel
              ? MTNowPlayingPanel(
                  handler: handler,
                  artwork: artworkBuilderFor(ref),
                  cover: coverBuilderFor(ref),
                  companion: audioTranscriptPanels(context, handler),
                  onOpen: () => GoRouter.of(context).push('/audio'),
                  onCollapse: () => setState(() => _panelFolded = true),
                )
              : null,
          items: _navItems(l10n),
          selectedIndex: branch,
          onSelected: widget.navigationShell.goBranch,
          body: widget.navigationShell,
          floatingActionButtonAnimator:
              FloatingActionButtonAnimator.noAnimation,
          floatingActionButton: MTHiddenUnderRoutes(
            // It hides under any sheet or dialog: it used to cover the "about
            // this clip" link and crowd the bottom sheets' actions (field
            // report 2026-09-02).
            visible: branch != 2,
            child: MTFab(
              label: clipboardUrl == null
                  ? l10n.addLinkFab
                  : l10n.clipboardLinkReady,
              highlighted: clipboardUrl != null,
              onPressed: _onFabPressed,
            ),
          ),
          // The mini player is a permanent bar **above** the bottom bar, inside
          // the same slot so Scaffold accounts for its height and lifts the add
          // button over it (log §4).
          bottomAccessories: [
            // **The clipboard bar**: changing the floating button's label
            // alone was too faint a signal, the link itself was never
            // visible, and there was no way to open the options instead of
            // downloading immediately. The bar shows the link and offers both
            // actions.
            if (branch != 2 &&
                clipboardUrl != null &&
                clipboardUrl != _dismissedClipboardUrl)
              MTClipboardBanner(
                url: clipboardUrl,
                title: l10n.clipboardFound,
                downloadLabel: l10n.downloadNow,
                optionsLabel: l10n.chooseOptions,
                onDownload: () {
                  // An explicit button labelled "download now" with "choose
                  // options" beside it; it does not pass through the
                  // setting's gate.
                  if (startQuickDownload(
                    context,
                    ref,
                    clipboardUrl,
                    explicit: true,
                  )) {
                    ref.read(clipboardUrlProvider.notifier).state = null;
                  } else {
                    openAddSheet(context, ref, initialUrl: clipboardUrl);
                  }
                },
                onOptions: () =>
                    openAddSheet(context, ref, initialUrl: clipboardUrl),
                onDismiss: _dismissClipboard,
              ),
            if (branch != 2 && !panel)
              MTMiniPlayer(
                handler: handler,
                // A square thumbnail, so the wide YouTube picture: the
                // letterboxed one shows its black bands.
                artwork: coverBuilderFor(ref),
                onOpen: () => GoRouter.of(context).push('/audio'),
                onExpand: roomForPanel
                    ? () => setState(() => _panelFolded = false)
                    : null,
              ),
          ],
        );
      },
    );
  }

  List<MTNavItem> _navItems(MTLocalizations l10n) => [
    MTNavItem(
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library_rounded,
      label: l10n.navLibrary,
    ),
    MTNavItem(
      icon: Icons.queue_music_outlined,
      selectedIcon: Icons.queue_music_rounded,
      label: l10n.navPlaylists,
    ),
    MTNavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: l10n.navSettings,
    ),
  ];
}

/// The clipboard check, callable from the shell.
final clipboardRefresherProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => refreshClipboardUrl(ref),
);
