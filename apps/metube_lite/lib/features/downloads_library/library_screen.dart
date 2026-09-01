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
import 'library_actions.dart';
import 'library_providers.dart';
import 'local_item.dart';
import 'widgets/downloads_sheet.dart';
import 'widgets/item_actions_sheet.dart';
import 'widgets/library_chips.dart';
import 'widgets/sort_sheet.dart';

/// «تحميلاتي» — المكتبة المحلية (م-12/م-14) بالنموذج أ: بطاقات حية أثناء
/// النشاط فقط + شارة عداد في الرأس تفتح ورقة الإدارة؛ البحث ظاهر دائماً.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final options = ref.watch(libraryViewProvider);
    final active = ref.watch(activeTasksProvider);
    final settings = ref.watch(settingsProvider);

    // المكتبة محلية: تعمل بلا سيرفر — الحالة الفارغة تدعو للإعداد فقط
    // حين لا يوجد سيرفر **ولا ملفات**.
    final items = ref.watch(localMediaProvider).value ?? const [];
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
                ref.invalidate(localMediaProvider);
                await ref.read(localMediaProvider.future);
              },
              child: _body(l10n, options, active),
            ),
    );
  }

  AppBar _mainAppBar(MTLocalizations l10n, int activeCount) {
    final x = MTThemeX.of(context);
    return AppBar(
      title: Text(l10n.navMyDownloads),
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
          onPressed: () => ref
              .read(libraryActionsProvider)
              .share(_selectedItems(selection)),
          icon: const Icon(Icons.share_rounded),
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
  List<LocalItem> _selectedItems(Set<String> selection) {
    final visible = ref.read(visibleLibraryProvider).value ?? const [];
    return [
      for (final item in visible)
        if (selection.contains(item.key)) item,
    ];
  }

  /// **بناء كسول إلزامي** (درس أداء المرحلة 6): الرأس شريحة والعناصر
  /// `SliverList.builder` لا تبني إلا المرئي.
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
              const LibraryFilterChips(),
              const SizedBox(height: MTSpace.xs),
              const PlatformFilterChips(),
              const SizedBox(height: MTSpace.md),
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
                  title: l10n.tryAgain,
                  message: l10n.noDownloadsMessage,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(localMediaProvider),
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
                      ? l10n.noDownloads
                      : l10n.noResults,
                  message: options.query.isEmpty
                      ? l10n.noDownloadsMessage
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

  Widget _taskCard(MTLocalizations l10n, DownloadTask task) {
    final engine = ref.read(downloadEngineProvider);
    final statusText = switch (task.phase) {
      TaskPhase.queued => l10n.queuedSection,
      TaskPhase.adding || TaskPhase.polling => l10n.onServerProgress(
          (task.progress * 100).toStringAsFixed(0)),
      TaskPhase.pulling => l10n.pullingToDevice,
      // Lite ينظف السيرفر بعد السحب — مرحلة قصيرة تستحق نصاً صريحاً.
      TaskPhase.deleting => l10n.cleaningServer,
      TaskPhase.failed => taskErrorText(l10n, task),
      _ => l10n.completed,
    };
    return MTDownloadProgressCard(
      title: task.title ?? task.effectiveUrl,
      statusText: statusText,
      progress: task.phase == TaskPhase.queued ? null : task.progress,
      isError: task.phase == TaskPhase.failed,
      onCancel: () => engine?.cancel(task.id),
    );
  }

  /// ر-4: نقرة عنصر — صوتي ⇒ تشغيل خلفي فوراً؛ مرئي ⇒ `/player`
  /// (والعمودي القصير ⇒ الريلز م-35). قائمة التشغيل الداخلية =
  /// **المكتبة المعروضة** وقت النقر بنفس فرزها وتصفيتها.
  Future<void> _play(LocalItem tapped) async {
    final visible = ref.read(visibleLibraryProvider).value ?? const [];
    final items = [for (final item in visible) toPlaylistItem(item)];
    final index = visible.indexWhere((i) => i.key == tapped.key);
    if (items.isEmpty || index < 0) return;

    if (tapped.isAudio) {
      await ref.read(audioHandlerProvider).playItems(items, startIndex: index);
      return;
    }
    ref.read(playbackRequestProvider.notifier).state =
        PlaybackRequest(items: items, startIndex: index);
    if (!mounted) return;
    context.push(tapped.isShortForm ? '/reels' : '/player');
  }

  Widget _itemCard(
      MTLocalizations l10n, LibraryViewOptions options, LocalItem item) {
    final controller = ref.read(libraryViewProvider.notifier);
    final actions = ref.read(libraryActionsProvider);
    final highlighted = ref.watch(highlightedItemProvider) == item.key;
    return MTMediaCard(
      title: item.title,
      subtitle: [
        mtTimeAgo(context, item.modified),
        '${(item.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
      ].join(' · '),
      thumbnail: item.thumbnail == null
          ? null
          : CachedNetworkImage(
              imageUrl: item.thumbnail!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
      platform: platformKindOf(item.platform),
      location: MTMediaLocation.offline,
      locationLabel: l10n.availabilityOffline,
      compact: options.compact,
      favorite: item.favorite,
      selected: options.selection.contains(item.key) || highlighted,
      onFavoriteToggle: () async {
        final added = await actions.toggleFavorite(item.key);
        if (!mounted) return;
        showMTSnack(context,
            added ? l10n.addedToFavorites : l10n.removedFromFavorites);
      },
      onTap: options.selecting
          ? () => controller.toggleSelected(item.key)
          : () => _play(item),
      onLongPress: () => controller.toggleSelected(item.key),
      onMore: () => showItemActionsSheet(context, ref, item),
    );
  }
}
