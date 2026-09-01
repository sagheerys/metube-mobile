import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../home/add_flow.dart';
import '../player/playback_providers.dart';
import '../playlists/add_to_playlist_sheet.dart';
import '../tags/item_tags_sheet.dart';
import 'library_actions.dart';
import 'library_models.dart';
import 'library_providers.dart';
import 'widgets/downloads_sheet.dart';
import 'widgets/item_actions_sheet.dart';
import 'widgets/sort_sheet.dart';

/// المكتبة الموحدة (م-13/م-14) — النموذج أ: بطاقات حية أثناء النشاط فقط
/// + شارة عداد في الرأس تفتح ورقة الإدارة؛ البحث ظاهر دائماً.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  Timer? _livePoll;

  @override
  void dispose() {
    _livePoll?.cancel();
    super.dispose();
  }

  /// §2.3: تحديث حي كل 2s أثناء وجود نشاط فقط — يتوقف المؤقت بلا نشاط.
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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncLivePolling(active));

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
                ref.invalidate(historyProvider);
                await ref.read(libraryItemsProvider.future);
              },
              child: _body(l10n, options, active),
            ),
    );
  }

  AppBar _mainAppBar(MTLocalizations l10n, int activeCount) {
    final x = MTThemeX.of(context);
    return AppBar(
      title: Text(l10n.navLibrary),
      actions: [
        // شارة التحميلات النشطة (النموذج أ) — تفتح ورقة الإدارة.
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
        // زر واحد للفرز والعرض (النموذج أ).
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
            final items = ref.read(visibleLibraryProvider).value ?? [];
            controller.selectAll(items.map((i) => i.canonicalUrl));
          },
          icon: const Icon(Icons.select_all_rounded),
        ),
        IconButton(
          tooltip: l10n.addToPlaylist,
          onPressed: () => showAddToPlaylistSheet(
              context, ref, _selectedItems(selection)),
          icon: const Icon(Icons.playlist_add_rounded),
        ),
        IconButton(
          tooltip: l10n.tags,
          onPressed: () =>
              showItemTagsSheet(context, ref, selection.toList()),
          icon: const Icon(Icons.sell_outlined),
        ),
        IconButton(
          tooltip: l10n.deleteSelected,
          onPressed: () => confirmBulkDelete(context, ref, selection),
          icon: Icon(Icons.delete_outline_rounded,
              color: MTThemeX.of(context).palette.err),
        ),
      ],
    );
  }

  /// عناصر المكتبة المقابلة للتحديد الحالي (ر-6).
  List<LibraryItem> _selectedItems(Set<String> selection) {
    final visible = ref.read(visibleLibraryProvider).value ?? const [];
    return [
      for (final item in visible)
        if (selection.contains(item.canonicalUrl)) item,
    ];
  }

  /// **بناء كسول إلزامي:** مكتبة المالك الحقيقية 251 عنصراً — بناء
  /// الكل دفعة واحدة داخل `Column` كان يجمّد التطبيق حتى ANR. الرأس
  /// والبطاقات الحية شريحة، والعناصر `SliverList.builder` لا تبني إلا
  /// المرئي (متطلب «قوائم كبيرة سلسة» في `01-PRD.md` §2.7).
  Widget _body(MTLocalizations l10n, LibraryViewOptions options,
      List<DownloadTask> active) {
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
              _filterChips(l10n, options),
              const SizedBox(height: MTSpace.md),
              // بطاقات حية أعلى المكتبة أثناء النشاط فقط (النموذج أ).
              for (final task in active) ...[
                _taskCard(l10n, task),
                const SizedBox(height: MTSpace.xs),
              ],
              if (active.isNotEmpty) const SizedBox(height: MTSpace.sm),
            ],
          ),
        ),
        ...switch (itemsAsync) {
          AsyncLoading() => [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          AsyncError() => [
              SliverToBoxAdapter(
                child: MTEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.connectionFailed,
                  message: l10n.errNetwork,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(historyProvider),
                ),
              ),
            ],
          AsyncValue(:final value?) when value.isEmpty => [
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
          AsyncValue(:final value?) => [
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
                sliver: SliverList.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) =>
                      _itemCard(l10n, options, value[index]),
                ),
              ),
            ],
          _ => const <Widget>[],
        },
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }

  Widget _filterChips(MTLocalizations l10n, LibraryViewOptions options) {
    final controller = ref.read(libraryViewProvider.notifier);
    final x = MTThemeX.of(context);
    ChoiceChip chip(String label, bool selected, VoidCallback onTap,
            {Color? selectedColor}) =>
        ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: selectedColor,
          labelStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: selected ? x.palette.bg : x.palette.ink2),
          onSelected: (_) => onTap(),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // وسم نشط قادم من تبويب «وسومك» — نقرته تلغيه (م-37/ج).
          if (options.tag != null) ...[
            InputChip(
              label: Text('# ${options.tag}'),
              selected: true,
              showCheckmark: false,
              selectedColor: x.palette.offlineSoft,
              onDeleted: () => controller.setTag(null),
              onSelected: (_) => controller.setTag(null),
            ),
            const SizedBox(width: MTSpace.xs),
          ],
          chip(l10n.filterAll, options.scope == LibraryScope.all,
              () => controller.setScope(LibraryScope.all)),
          const SizedBox(width: MTSpace.xs),
          // م-36: رقاقة المفضلة أول المرشحات بعد «الكل».
          chip('♥ ${l10n.favorites}',
              options.scope == LibraryScope.favorites,
              () => controller.setScope(LibraryScope.favorites),
              selectedColor: x.palette.favorite),
          const SizedBox(width: MTSpace.xs),
          chip(l10n.filterOffline, options.scope == LibraryScope.offline,
              () => controller.setScope(LibraryScope.offline)),
          const SizedBox(width: MTSpace.xs),
          chip(l10n.filterServer, options.scope == LibraryScope.onServer,
              () => controller.setScope(LibraryScope.onServer)),
          const SizedBox(width: MTSpace.md),
          chip(l10n.filterVideo, options.type == MediaTypeFilter.video,
              () => controller.setType(
                  options.type == MediaTypeFilter.video
                      ? MediaTypeFilter.all
                      : MediaTypeFilter.video)),
          const SizedBox(width: MTSpace.xs),
          chip(l10n.filterAudio, options.type == MediaTypeFilter.audio,
              () => controller.setType(
                  options.type == MediaTypeFilter.audio
                      ? MediaTypeFilter.all
                      : MediaTypeFilter.audio)),
          const SizedBox(width: MTSpace.xs),
          // م-35: رقاقة «⚡ قِصار» تجمع العمودية القصيرة.
          chip('⚡ ${l10n.shortsFilter}',
              options.type == MediaTypeFilter.shorts,
              () => controller.setType(
                  options.type == MediaTypeFilter.shorts
                      ? MediaTypeFilter.all
                      : MediaTypeFilter.shorts)),
        ],
      ),
    );
  }

  Widget _taskCard(MTLocalizations l10n, DownloadTask task) {
    final engine = ref.read(downloadEngineProvider);
    final statusText = switch (task.phase) {
      TaskPhase.queued => l10n.queuedSection,
      TaskPhase.adding || TaskPhase.polling => l10n.onServerProgress(
          (task.progress * 100).toStringAsFixed(0)),
      TaskPhase.pulling => l10n.pullingToDevice,
      TaskPhase.deleting => l10n.downloading,
      TaskPhase.failed => taskErrorText(l10n, task),
      _ => l10n.completed,
    };
    return MTDownloadProgressCard(
      title: task.effectiveUrl,
      statusText: statusText,
      progress: task.phase == TaskPhase.queued ? null : task.progress,
      isError: task.phase == TaskPhase.failed,
      onCancel: () => engine?.cancel(task.id),
    );
  }

  /// ر-4: نقرة عنصر — صوتي ⇒ تشغيل خلفي فوراً وظهور المشغل المصغر؛
  /// مرئي ⇒ `/player`. قائمة التشغيل الداخلية = **المكتبة المعروضة**
  /// وقت النقر بنفس فرزها وتصفيتها.
  Future<void> _play(LibraryItem tapped) async {
    final visible = ref.read(visibleLibraryProvider).value ?? const [];
    final items = [for (final item in visible) toPlaylistItem(item)];
    final index =
        visible.indexWhere((i) => i.canonicalUrl == tapped.canonicalUrl);
    if (items.isEmpty || index < 0) return;

    if (tapped.isAudio) {
      await ref.read(audioHandlerProvider).playItems(items, startIndex: index);
      return;
    }
    ref.read(playbackRequestProvider.notifier).state =
        PlaybackRequest(items: items, startIndex: index);
    if (!mounted) return;
    // م-35: العمودي القصير يفتح في الريلز؛ غيره في المشغل العادي.
    context.push(tapped.isShortForm ? '/reels' : '/player');
  }

  Widget _itemCard(
      MTLocalizations l10n, LibraryViewOptions options, LibraryItem item) {
    final controller = ref.read(libraryViewProvider.notifier);
    final actions = ref.read(libraryActionsProvider);
    return MTMediaCard(
      title: item.title,
      subtitle: [
        if (item.uploader != null) item.uploader!,
        if (item.timestamp != null) mtTimeAgo(context, item.timestamp!),
      ].join(' · '),
      thumbnail: item.thumbnail == null
          ? null
          : CachedNetworkImage(
              imageUrl: item.thumbnail!,
              httpHeaders:
                  ref.read(apiClientProvider)?.streamingHeaders,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
      platform: platformKindOf(MediaPlatform.detect(item.canonicalUrl)),
      location: item.location,
      locationLabel: switch (item.location) {
        MTMediaLocation.offline ||
        MTMediaLocation.both =>
          l10n.availabilityOffline,
        MTMediaLocation.onServer => l10n.filterServer,
        MTMediaLocation.none => null,
      },
      compact: options.compact,
      favorite: item.favorite,
      selected: options.selection.contains(item.canonicalUrl),
      onFavoriteToggle: () async {
        final added = await actions.toggleFavorite(item.canonicalUrl);
        if (!mounted) return;
        showMTSnack(
          context,
          added ? l10n.addedToFavorites : l10n.removedFromFavorites,
        );
      },
      onTap: options.selecting
          ? () => controller.toggleSelected(item.canonicalUrl)
          : () => _play(item),
      onLongPress: () => controller.toggleSelected(item.canonicalUrl),
      onMore: () => showItemActionsSheet(context, ref, item),
    );
  }
}
