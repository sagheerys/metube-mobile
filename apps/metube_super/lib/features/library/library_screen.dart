import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:mt_media/library.dart';

import '../../di.dart';
import '../home/add_flow.dart';
import '../shared/error_text.dart';
import '../player/playback_providers.dart';
import '../settings/settings_sections.dart';
import '../transcripts/transcript_results.dart';
import 'library_providers.dart';
import 'widgets/downloads_sheet.dart';
import 'widgets/task_card_parts.dart';
import 'widgets/library_cards.dart';
import 'widgets/library_app_bars.dart';
import 'widgets/library_chips.dart';
import 'widgets/server_banner.dart';
import 'widgets/server_failures_section.dart';

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

  /// The search field is open in the bar's place.
  bool _searchOpen = false;

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

    final searching = _searchOpen || options.query.isNotEmpty;
    void closeSearch() {
      setState(() => _searchOpen = false);
      ref.read(libraryViewProvider.notifier).setQuery('');
    }

    // Back closes the search first, rather than leaving the app.
    return PopScope(
      canPop: !searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) closeSearch();
      },
      child: Scaffold(
        // Selecting swaps the bar with a short fade rather than a cut.
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: MTAnimatedSwap(
            child: KeyedSubtree(
              key: ValueKey(options.selecting),
              child: options.selecting
                  ? librarySelectionBar(context, ref, options)
                  : libraryMainBar(
                      context,
                      ref,
                      activeCount: active.length,
                      searching: searching,
                      onSearch: () => setState(() => _searchOpen = true),
                      onCloseSearch: closeSearch,
                    ),
            ),
          ),
        ),
        body: !settings.isConfigured
            ? MTEmptyState(
                title: l10n.noServerTitle,
                message: l10n.noServerMessage,
                actionLabel: l10n.setupServer,
                onAction: () => context.go(SettingsPane.server.route),
              )
            : MTPullRefresh(
                onRefresh: () async {
                  // A failed refresh is shown by the library itself, and
                  // rethrowing here escapes the `RefreshIndicator` with nobody
                  // to catch it.
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
                // A wide grid gains columns, and a tablet spreads every mode
                // across its width; a phone's rows and cards keep theirs.
                child: MTRevealOnce(
                  child:
                      options.mode == LibraryViewMode.grid ||
                          MTAdaptiveScaffold.hasRail(context)
                      ? _body(l10n, options, active)
                      : MTReadableWidth(child: _body(l10n, options, active)),
                ),
              ),
      ),
    );
  }

  /// **Lazy building is mandatory:** a real library holds 251 items, and
  /// building them all at once inside a `Column` froze the app to the point
  /// of an ANR. The header and the live cards are slivers, and the items
  /// are a `SliverList.builder` that builds only what is visible, so a
  /// large list stays smooth.
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
              const SizedBox(height: MTSpace.xs),
              const LibraryFilterChips(),
              // "Is a filter on?" is a question every compound filter
              // raises, and one line answers it without the user opening
              // anything.
              if (options.query.isNotEmpty || options.activeFilters > 0)
                Padding(
                  padding: const EdgeInsets.only(top: MTSpace.xs),
                  child: Text(
                    l10n.resultsFound(ref.watch(libraryResultCountProvider)),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              const SizedBox(height: MTSpace.md),
              // Why the server part is missing, when it is (2026-09-13).
              const LibraryServerBanner(),
              // Failures the server holds, from anywhere: one line, and
              // nothing when there are none.
              ServerFailuresLine(
                onOpen: () => showDownloadsSheet(context, toFailures: true),
              ),
              ..._activeStrip(l10n, active),
            ],
          ),
        ),
        ...switch (itemsAsync) {
          AsyncValue(valueOrNull: final value?) when value.isNotEmpty => [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
              sliver: MTLibrarySliver(
                layout: options.mode.layout,
                itemCount: value.length,
                showLocation: true,
                itemBuilder: (context, index, columns) =>
                    _card(value[index], columns),
              ),
            ),
          ],
          // The page keeps its shape while the first answer comes.
          AsyncLoading() => [
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
              sliver: MTRowsSkeleton(),
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
                      title: l10n.signInRequired,
                      // The saved password is not the problem when it was
                      // Cloudflare that said no.
                      message: error is AccessRejectedException
                          ? l10n.errAccessRejected
                          : l10n.signInRequiredHint,
                      actionLabel: l10n.updateCredentials,
                      onAction: () => context.go(SettingsPane.server.route),
                    )
                  : MTEmptyState(
                      title: l10n.connectionFailed,
                      message: errorText(l10n, error),
                      actionLabel: l10n.retry,
                      onAction: () => ref.invalidate(historyProvider),
                    ),
            ),
          ],
          // Words found only inside clips are still results: the
          // transcript matches below stand in for the empty state.
          AsyncValue(valueOrNull: final value?)
              when value.isEmpty &&
                  ref.watch(transcriptResultsProvider).isEmpty =>
            [
              SliverToBoxAdapter(
                // **Say why it is empty** (audit 2026-10-30): with the
                // offline chip on and nothing kept here, a full library
                // was announced as "Your library is empty".
                child: switch (options) {
                  LibraryViewOptions(query: final q) when q.isNotEmpty =>
                    MTEmptyState(
                      title: l10n.noResults,
                      message: l10n.noResultsMessage,
                    ),
                  LibraryViewOptions(scope: LibraryScope.offline) =>
                    MTEmptyState(
                      title: l10n.emptyOfflineTitle,
                      message: l10n.emptyOfflineMessage,
                    ),
                  LibraryViewOptions(narrowed: true) => MTEmptyState(
                    title: l10n.emptyFilteredTitle,
                    message: l10n.emptyFilteredMessage,
                  ),
                  _ => MTEmptyState(
                    title: l10n.noVideosFound,
                    message: l10n.emptyLibraryMessage,
                  ),
                },
              ),
            ],
          _ => const <Widget>[],
        },
        const TranscriptResultsSliver(),
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
      TaskPhase.adding || TaskPhase.polling => l10n.onServerPhase,
      TaskPhase.waitingForNetwork => l10n.waitingForWifi,
      TaskPhase.pulling => l10n.pullingToDevice,
      TaskPhase.deleting => l10n.downloading,
      TaskPhase.failed => taskErrorText(l10n, task),
      _ => l10n.completed,
    };
    return MTDownloadProgressCard(
      key: ValueKey('${task.id}-${task.phase.name}'),
      title: task.title ?? task.effectiveUrl,
      thumbnail: taskThumbnail(ref, task),
      detail: taskSpeed(task),
      waiting: task.phase == TaskPhase.queued,
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
    // A short portrait clip opens in reels, anything else in the player.
    context.push(tapped.isShortForm ? '/reels' : '/player');
  }

  /// The card reads the mode from the options itself; it is not passed
  /// twice.
  Widget _card(LibraryItem item, MTMediaColumns? columns) =>
      LibraryItemCard(item: item, columns: columns, onPlay: () => _play(item));
}
