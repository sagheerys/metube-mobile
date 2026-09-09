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
import 'library_actions.dart';
import 'library_providers.dart';
import 'local_item.dart';
import 'widgets/downloads_sheet.dart';
import 'widgets/item_actions_sheet.dart';
import 'widgets/library_cards.dart';
import 'widgets/library_chips.dart';
import 'widgets/sort_sheet.dart';

/// "My downloads", the local library: live cards only while something is
/// active, plus a counter badge in the header that opens the management
/// sheet. Search is always visible.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// The highlight from a completion-notification tap is **temporary**. It
  /// used to be set and never cleared, so the item kept a "selected" look
  /// forever (field report 2026-09-02).
  static const highlightDuration = Duration(seconds: 6);
  Timer? _highlightTimer;

  void _clearHighlight() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    if (ref.read(highlightedItemProvider) != null) {
      ref.read(highlightedItemProvider.notifier).state = null;
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    ref.listen<String?>(highlightedItemProvider, (_, next) {
      _highlightTimer?.cancel();
      if (next == null) return;
      _highlightTimer = Timer(highlightDuration, () {
        if (mounted) _clearHighlight();
      });
    });
    final options = ref.watch(libraryViewProvider);
    final active = ref.watch(activeTasksProvider);
    final settings = ref.watch(settingsProvider);

    // The library is local and works with no server, so the empty state
    // invites configuration only when there is no server **and no files**.
    final items = ref.watch(localMediaProvider).valueOrNull ?? const [];
    final needsSetup = !settings.isConfigured && items.isEmpty;

    return Scaffold(
      appBar: options.selecting
          ? _selectionAppBar(l10n, options)
          : _mainAppBar(l10n, active.length),
      body: needsSetup
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
                ref.invalidate(localMediaProvider);
                try {
                  await ref.read(localMediaProvider.future);
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
      title: Text(l10n.navMyDownloads),
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
            controller.selectAll(items.map((i) => i.key));
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
          tooltip: l10n.shareSelected,
          onPressed: () =>
              ref.read(libraryActionsProvider).share(_selectedItems(selection)),
          icon: const Icon(Icons.share_rounded),
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

  /// The library items matching the current selection (rule 6).
  List<LocalItem> _selectedItems(Set<String> selection) {
    final visible = ref.read(visibleLibraryProvider).valueOrNull ?? const [];
    return [
      for (final item in visible)
        if (selection.contains(item.key)) item,
    ];
  }

  /// **Lazy building is mandatory** (a performance lesson from phase 6):
  /// the header is a sliver and the items are a `SliverList.builder` that
  /// builds only what is visible.
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
              const SizedBox(height: MTSpace.xs),
              const PlatformFilterChips(),
              const SizedBox(height: MTSpace.md),
              ..._activeStrip(l10n, active),
            ],
          ),
        ),
        // **The order of the cases is deliberate** (field report
        // 2026-09-02): every library invalidation passes through
        // `AsyncLoading` **while keeping the previous data**, and matching
        // that first replaced the list with a spinner for a fraction of a
        // second, a continuous flicker during downloads, when the library
        // refreshes repeatedly. Existing data always wins, and a spinner
        // appears only on the very first load.
        ...switch (itemsAsync) {
          AsyncValue(valueOrNull: final value?) when value.isNotEmpty => [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
              // Every mode is lazy: `builder` builds only what is
              // visible. The ratio and the sizes are the ones measured in
              // Super.
              sliver: switch (options.mode) {
                LibraryViewMode.grid => SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 210,
                    mainAxisSpacing: MTSpace.md,
                    crossAxisSpacing: MTSpace.md,
                    childAspectRatio: 1.02,
                  ),
                  itemCount: value.length,
                  itemBuilder: (context, index) => _itemCard(value[index]),
                ),
                LibraryViewMode.cards => SliverList.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) => Padding(
                    // Cards carry no divider; the space is the divider.
                    padding: const EdgeInsets.only(bottom: MTSpace.lg),
                    child: _itemCard(value[index]),
                  ),
                ),
                _ => SliverList.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) => _itemCard(value[index]),
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
          // The message comes from the error itself rather than from a
          // fixed string (the same cure as Super).
          AsyncError(:final error) => [
            SliverToBoxAdapter(
              child: MTEmptyState(
                icon: Icons.error_outline_rounded,
                title: l10n.tryAgain,
                message: errorText(l10n, error),
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(localMediaProvider),
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
                    ? l10n.noDownloads
                    : l10n.noResults,
                message: options.query.isEmpty
                    ? l10n.noDownloadsMessage
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
  /// summary line.**
  ///
  /// Field report 2026-09-03: "several downloads all appear in the
  /// downloads library while a button for them already sits in the header.
  /// Find a way to stop them crowding one place."
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
      // **No percentage in the text**: the counter became an independent
      // element in the card, so keeping it here printed it twice ("on
      // server · 0%" beside "0%"), spotted in a screenshot.
      TaskPhase.adding || TaskPhase.polling => l10n.onServerPhase,
      TaskPhase.waitingForNetwork => l10n.waitingForWifi,
      TaskPhase.pulling => l10n.pullingToDevice,
      // Lite cleans the server after pulling, a short phase that deserves
      // to be named explicitly.
      TaskPhase.deleting => l10n.cleaningServer,
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

  /// Rule 4: tapping an item. Audio plays in the background immediately;
  /// video opens `/player`, and a short portrait clip opens reels. The
  /// internal play queue is **the library as displayed** at the moment of
  /// the tap, with the same sorting and filtering.
  Future<void> _play(LocalItem tapped) async {
    final visible = ref.read(visibleLibraryProvider).valueOrNull ?? const [];
    final items = [for (final item in visible) toPlaylistItem(item)];
    final index = visible.indexWhere((i) => i.key == tapped.key);
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
    context.push(tapped.isShortForm ? '/reels' : '/player');
  }

  /// The card reads the mode from the options itself; it is not passed
  /// twice.
  Widget _itemCard(LocalItem item) => LibraryItemCard(
    item: item,
    onPlay: () => _play(item),
    onClearHighlight: _clearHighlight,
  );
}
