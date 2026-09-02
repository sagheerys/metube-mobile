import 'dart:async';

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
import 'library_models.dart';
import 'library_providers.dart';
import 'widgets/downloads_sheet.dart';
import 'widgets/item_actions_sheet.dart' show confirmBulkDelete;
import 'widgets/library_cards.dart';
import 'widgets/library_chips.dart';
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

  /// التوهج يتلاشى بصرياً وحده؛ هذا المؤقت يطفئ **الحالة** بعده كي لا
  /// يعود العنصر متوهجاً كلما مرّ أمام العين في التمرير.
  static const _highlightLinger = Duration(seconds: 8);
  Timer? _highlightTimer;

  @override
  void dispose() {
    _livePoll?.cancel();
    _highlightTimer?.cancel();
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
    ref.listen<String?>(highlightedItemProvider, (_, next) {
      _highlightTimer?.cancel();
      if (next == null) return;
      _highlightTimer = Timer(_highlightLinger, () {
        if (mounted) {
          ref.read(highlightedItemProvider.notifier).state = null;
        }
      });
    });
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
              // ظهور واحد هادئ للمحتوى عند أول بناء — لا حركة لكل
              // بطاقة (كانت تُنطّ القائمة طوال التمرير).
              child: MTRevealOnce(child: _body(l10n, options, active)),
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
              const LibraryFilterChips(),
              // «هل التصفية شغّالة؟» — سؤال يطرحه كل مرشح مركّب، وسطر
              // واحد يجيب عنه بلا أن يفتح المستخدم شيئاً.
              if (options.query.isNotEmpty || options.activeFilters > 0)
                Padding(
                  padding: const EdgeInsets.only(top: MTSpace.xs),
                  child: Text(
                    l10n.resultsFound(itemsAsync.value?.length ?? 0),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
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
        // **البيانات الموجودة تفوز على حالة التحميل** (نفس علاج وميض
        // Lite): الاستطلاع الحي كل ثانيتين يُبطل السجل، وكل إبطال يمر
        // بـ `AsyncLoading` محتفظاً ببياناته — مطابقتها أولاً كانت
        // تستبدل المكتبة بدوّارة مرتين في الثانية أثناء أي تحميل.
        ...switch (itemsAsync) {
          AsyncValue(:final value?) when value.isNotEmpty => [
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
                sliver: options.grid
                    // الشبكة كسولة أيضاً — `SliverGrid.builder` لا يبني
                    // إلا المرئي، وهو شرط 251 عنصراً بلا تجميد.
                    ? SliverGrid.builder(
                        // **النسبة مقيسة لا مقدَّرة** (تحقق بلقطة على
                        // المحاكي): 0.82 تركت ~50 نقطة فراغاً ميتاً تحت
                        // كل بطاقة فبدت الشبكة مفكّكة. المحتوى الفعلي =
                        // غلاف 16:9 + سطرا عنوان + سطر بيانات.
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 210,
                          mainAxisSpacing: MTSpace.md,
                          crossAxisSpacing: MTSpace.md,
                          childAspectRatio: 1.02,
                        ),
                        itemCount: value.length,
                        itemBuilder: (context, index) =>
                            _gridCard(l10n, options, value[index]),
                      )
                    : SliverList.builder(
                        itemCount: value.length,
                        itemBuilder: (context, index) =>
                            _itemCard(l10n, options, value[index]),
                      ),
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
      TaskPhase.waitingForNetwork => l10n.waitingForWifi,
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
          MTLocalizations l10n, LibraryViewOptions options, LibraryItem item) =>
      LibraryItemCard(item: item, onPlay: () => _play(item));

  Widget _gridCard(
          MTLocalizations l10n, LibraryViewOptions options, LibraryItem item) =>
      LibraryItemCard(item: item, onPlay: () => _play(item), grid: true);
}
