import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../home/add_flow.dart';
import '../shared/error_text.dart';
import '../player/playback_providers.dart';
import '../playlists/add_to_playlist_sheet.dart';
import '../tags/item_tags_sheet.dart';
import 'library_models.dart';
import 'library_providers.dart';
import 'widgets/downloads_sheet.dart';
import 'widgets/item_actions_sheet.dart' show confirmBulkDelete;
import 'widgets/library_cards.dart';
import 'widgets/library_chips.dart';
import 'widgets/sort_sheet.dart';

/// The unified library: live cards only while something is active, plus a
/// counter badge in the header that opens the management sheet. Search is
/// always visible.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  Timer? _livePoll;

  /// The highlight fades visually on its own; this timer clears the
  /// **state** afterwards, so the item does not glow again every time it
  /// scrolls past.
  static const _highlightLinger = Duration(seconds: 8);
  Timer? _highlightTimer;

  @override
  void dispose() {
    _livePoll?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  /// §2.3: a live refresh every 2s while something is active; the timer
  /// stops when nothing is.
  void _syncLivePolling(List<DownloadTask> active) {
    if (active.isEmpty) {
      _livePoll?.cancel();
      _livePoll = null;
    } else {
      _livePoll ??= Timer.periodic(MTConstants.livePollInterval, (_) {
        ref.invalidate(historyProvider);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final active = ref.watch(activeTasksProvider);
    final settings = ref.watch(settingsProvider);
    ref.listen<String?>(highlightedItemProvider, (_, next) {
      _highlightTimer?.cancel();
      if (next == null) return;
      _highlightTimer = Timer(_highlightLinger, () {
        if (mounted) {
          ref.read(highlightedItemProvider.notifier).state = null;
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncLivePolling(active),
    );

    return Scaffold(
      appBar: options.selecting
          ? _selectionAppBar(l10n, options)
          : _mainAppBar(l10n, active.length),
      body: !settings.isConfigured
          ? MTEmptyState(
              icon: Icons.cloud_off_rounded,
              title: l10n.noServerTitle,
              message: l10n.noServerMessage,
              actionLabel: l10n.setupServer,
              onAction: () => context.go('/settings'),
            )
          : RefreshIndicator(
              onRefresh: () async {
                // A failed refresh is shown by the library itself in its
                // empty state, and
                // rethrowing here escapes the `RefreshIndicator` with
                // nobody to catch
                // it.
                ref.invalidate(historyProvider);
                try {
                  await ref.read(libraryItemsProvider.future);
                } on MTApiException {
                  // Shown in the empty state.
                }
              },
              // One calm appearance of the content on the first build,
              // rather than motion per card, which made the list bounce
              // throughout the scroll.
              child: MTRevealOnce(child: _body(l10n, options, active)),
            ),
    );
  }

  AppBar _mainAppBar(MTLocalizations l10n, int activeCount) {
    final x = MTThemeX.of(context);
    return AppBar(
      title: Text(l10n.navLibrary),
      actions: [
        // The active downloads badge, which opens the management sheet.
        IconButton(
          tooltip: l10n.activeDownloadsSheet,
          onPressed: () => showDownloadsSheet(context),
          icon: Badge(
            isLabelVisible: activeCount > 0,
            label: Text('$activeCount'),
            backgroundColor: x.palette.accent,
            textColor: x.palette.onAccent,
            child: const Icon(Icons.download_rounded),
          ),
        ),
        // One button for sorting and the view mode.
        IconButton(
          tooltip: l10n.sortBy,
          onPressed: () => showSortSheet(context, ref),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }

  AppBar _selectionAppBar(MTLocalizations l10n, LibraryViewOptions options) {
    final controller = ref.read(libraryViewProvider.notifier);
    final selection = options.selection;
    return AppBar(
      leading: IconButton(
        onPressed: controller.clearSelection,
        icon: const Icon(Icons.close_rounded),
      ),
      title: Text(l10n.selectedCount(selection.length)),
      actions: [
        IconButton(
          tooltip: l10n.selectAll,
          onPressed: () {
            final items = ref.read(visibleLibraryProvider).valueOrNull ?? [];
            controller.selectAll(items.map((i) => i.canonicalUrl));
          },
          icon: const Icon(Icons.select_all_rounded),
        ),
        IconButton(
          tooltip: l10n.addToPlaylist,
          onPressed: () =>
              showAddToPlaylistSheet(context, ref, _selectedItems(selection)),
          icon: const Icon(Icons.playlist_add_rounded),
        ),
        IconButton(
          tooltip: l10n.tags,
          onPressed: () => showItemTagsSheet(context, ref, selection.toList()),
          icon: const Icon(Icons.sell_outlined),
        ),
        IconButton(
          tooltip: l10n.deleteSelected,
          onPressed: () => confirmBulkDelete(context, ref, selection),
          icon: Icon(
            Icons.delete_outline_rounded,
            color: MTThemeX.of(context).palette.err,
          ),
        ),
      ],
    );
  }

  /// **Lazy building is mandatory:** a real library holds 251 items, and
  /// building them all at once inside a `Column` froze the app to the point
  /// of an ANR. The header and the live cards are slivers, and the items
  /// are
  /// a `SliverList.builder` that builds only what is visible (the "large
  /// lists stay smooth" requirement in `01-PRD.md` §2.7).
  List<LibraryItem> _selectedItems(Set<String> selection) {
    final visible = ref.read(visibleLibraryProvider).valueOrNull ?? const [];
    return [
      for (final item in visible)
        if (selection.contains(item.canonicalUrl)) item,
    ];
  }

  /// **Lazy building is mandatory:** a real library holds 251 items, and
  /// building them all at once inside a `Column` froze the app to the point
  /// of an ANR. The header and the live cards are slivers, and the items
  /// are a `SliverList.builder` that builds only what is visible (the
  /// "large lists stay smooth" requirement in `01-PRD.md` §2.7).
  Widget _body(
    MTLocalizations l10n,
    LibraryViewOptions options,
    List<DownloadTask> active,
  ) {
    final itemsAsync = ref.watch(visibleLibraryProvider);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
          sliver: SliverList.list(
            children: [
              MTSearchField(
                hint: l10n.searchVideos,
                onChanged: ref.read(libraryViewProvider.notifier).setQuery,
              ),
              const SizedBox(height: MTSpace.sm),
              const LibraryFilterChips(),
              // "Is a filter on?" is a question every compound filter
              // raises, and one line answers it without the user opening
              // anything.
              if (options.query.isNotEmpty || options.activeFilters > 0)
                Padding(
                  padding: const EdgeInsets.only(top: MTSpace.xs),
                  child: Text(
                    l10n.resultsFound(itemsAsync.valueOrNull?.length ?? 0),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              const SizedBox(height: MTSpace.md),
              // Every mode is lazy: `builder` builds only what is visible,
              // which is the
              // condition for 251 items without freezing. The fourth mode,
              // cards, is
              // the heaviest because every cover is the width of the
              // screen, and
              // laziness is what makes it possible at all: only three cards
              // are ever
              // visible.
              ..._activeStrip(l10n, active),
            ],
          ),
        ),
        // **The ratio is measured, not estimated** (verified with an
        // emulator
        // screenshot): 0.82 left about 50 points of dead space under every
        // card
        // and the grid looked disjointed. The real content is a 16:9 cover
        // plus
        // two title lines plus a meta line.
        ...switch (itemsAsync) {
          AsyncValue(valueOrNull: final value?) when value.isNotEmpty => [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
              // Every mode is lazy: `builder` builds only what is
              // visible, which is the condition for 251 items without
              // freezing. The fourth mode, cards, is the heaviest because
              // every cover is the width of the screen, and laziness is
              // what makes it possible at all: only three cards are ever
              // visible.
              sliver: switch (options.mode) {
                LibraryViewMode.grid => SliverGrid.builder(
                  // Cards carry no divider; the space is the divider.
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 210,
                    mainAxisSpacing: MTSpace.md,
                    crossAxisSpacing: MTSpace.md,
                    childAspectRatio: 1.02,
                  ),
                  itemCount: value.length,
                  itemBuilder: (context, index) => _card(value[index]),
                ),
                LibraryViewMode.cards => SliverList.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) => Padding(
                    // Cards carry no divider; the space is the divider.
                    padding: const EdgeInsets.only(bottom: MTSpace.lg),
                    child: _card(value[index]),
                  ),
                ),
                _ => SliverList.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) => _card(value[index]),
                ),
              },
            ),
          ],
          AsyncLoading() => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
          // **The error states its cause**: the message used to be a fixed
          // `errNetwork` whatever the fault, so a rejected credential (401)
          // read as "could not reach the network", a wrong diagnosis that
          // sends the owner hunting through their router.
          AsyncError(:final error) => [
            SliverToBoxAdapter(
              child: error is AuthFailureException
                  ? MTEmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: l10n.signInRequired,
                      message: l10n.signInRequiredHint,
                      actionLabel: l10n.updateCredentials,
                      onAction: () => context.go('/settings'),
                    )
                  : MTEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: l10n.connectionFailed,
                      message: errorText(l10n, error),
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(historyProvider),
                    ),
            ),
          ],
          AsyncValue(valueOrNull: final value?) when value.isEmpty => [
            SliverToBoxAdapter(
              child: MTEmptyState(
                icon: options.query.isEmpty
                    ? Icons.video_library_outlined
                    : Icons.search_off_rounded,
                title: options.query.isEmpty
                    ? l10n.noVideosFound
                    : l10n.noResults,
                message: options.query.isEmpty
                    ? l10n.emptyLibraryMessage
                    : l10n.noResultsMessage,
              ),
            ),
          ],
          _ => const <Widget>[],
        },
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }

  /// **One task shows its full card; more than one collapses into a single
  /// summary line** (field report 2026-09-03: "several downloads all appear
  /// in the library while a button for them already sits in the header").
  /// All the detail stays in the management sheet as before.
  List<Widget> _activeStrip(MTLocalizations l10n, List<DownloadTask> active) {
    if (active.isEmpty) return const [];
    return [
      if (active.length == 1)
        _taskCard(l10n, active.first)
      else
        MTActiveDownloadsBar(
          label: l10n.activeDownloadsCount(active.length),
          actionLabel: l10n.viewAll,
          progress: averageTaskProgress(active),
          onTap: () => showDownloadsSheet(context),
        ),
      const SizedBox(height: MTSpace.sm),
    ];
  }

  Widget _taskCard(MTLocalizations l10n, DownloadTask task) {
    final engine = ref.read(downloadEngineProvider);
    final statusText = switch (task.phase) {
      TaskPhase.queued => l10n.queuedSection,
      // Rule 4: tapping an item. Audio plays in the background immediately
      // and
      // the mini player appears; video opens `/player`. The internal play
      // queue
      // is **the library as displayed** at the moment of the tap, with the
      // same
      // sorting and filtering.
      TaskPhase.adding || TaskPhase.polling => l10n.onServerPhase,
      TaskPhase.waitingForNetwork => l10n.waitingForWifi,
      TaskPhase.pulling => l10n.pullingToDevice,
      TaskPhase.deleting => l10n.downloading,
      TaskPhase.failed => taskErrorText(l10n, task),
      _ => l10n.completed,
    };
    return MTDownloadProgressCard(
      title: task.title ?? task.effectiveUrl,
      statusText: statusText,
      progress: task.hasKnownProgress ? task.progress : null,
      isError: task.phase == TaskPhase.failed,
      onCancel: () => engine?.cancel(task.id),
    );
  }

  /// Rule 4: tapping an item. Audio plays in the background immediately and
  /// the mini player appears; video opens `/player`. The internal play
  /// queue is **the library as displayed** at the moment of the tap, with
  /// the same sorting and filtering.
  Future<void> _play(LibraryItem tapped) async {
    final visible = ref.read(visibleLibraryProvider).valueOrNull ?? const [];
    final items = [for (final item in visible) toPlaylistItem(item)];
    final index = visible.indexWhere(
      (i) => i.canonicalUrl == tapped.canonicalUrl,
    );
    if (items.isEmpty || index < 0) return;

    if (tapped.isAudio) {
      await ref.read(audioHandlerProvider).playItems(items, startIndex: index);
      return;
    }
    ref.read(playbackRequestProvider.notifier).state = PlaybackRequest(
      items: items,
      startIndex: index,
    );
    if (!mounted) return;
    // A short portrait clip opens in reels; anything else in the normal
    // player.
    context.push(tapped.isShortForm ? '/reels' : '/player');
  }

  /// The card reads the mode from the options itself; it is not passed
  /// twice.
  Widget _card(LibraryItem item) =>
      LibraryItemCard(item: item, onPlay: () => _play(item));
}
