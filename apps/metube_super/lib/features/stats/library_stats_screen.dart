import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/library_providers.dart';
import '../library/widgets/item_details_sheet.dart';
import '../shared/platform_label.dart';
import '../transcripts/transcripts_state.dart';
import 'stats_parts.dart';

/// The library counted: its items, the transcripts on this phone while
/// they are on, and whether each clip was ever played here.
final libraryStatsProvider = FutureProvider.autoDispose<LibraryStats>((
  ref,
) async {
  final items = await ref.watch(libraryItemsProvider.future);
  final withText = await ref.watch(transcriptsEnabledProvider.future)
      ? await ref.watch(transcriptIndexProvider.future)
      : null;
  final positions = ref.watch(playbackPositionsProvider);
  final played = <String>{
    for (final item in items)
      if (await positions.stampOf(item.canonicalUrl) != null) item.canonicalUrl,
  };
  return statsOf(
    items,
    hasText: (url) => withText?.contains(url) ?? false,
    played: played.contains,
  );
});

/// **Your library** (mobile plan, stage 16/F, after the Windows app): how
/// many clips, how much room and how many hours, by site, channel and
/// month, and what may deserve a look. It counts and never deletes: a
/// site or a channel opens the library filtered to it, a clip its details.
class LibraryStatsScreen extends ConsumerWidget {
  const LibraryStatsScreen({super.key});

  /// How many clips each suggestion lists, and how many months show.
  static const _listed = 5;
  static const _months = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final stats = ref.watch(libraryStatsProvider);
    // **The last figures stay while new ones are counted.** The library
    // refreshes every few seconds, and a page swapped for a spinner each
    // time lost its height and threw the reader back to the top.
    return MTSettingsPage(
      title: l.yourLibrary,
      child: switch (stats.valueOrNull) {
        final value? when value.count > 0 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _figures(context, value),
            _bySite(context, ref, value),
            if (value.byChannel.isNotEmpty) _byChannel(context, ref, value),
            if (value.byMonth.length > 1) _byMonth(context, value),
            ..._suggestions(context, value),
          ],
        ),
        _? => MTEmptyState(title: l.noVideosFound, message: l.desktopStatsHint),
        null when stats.hasError => MTEmptyState(
          title: l.serverStatusOffline,
          message: l.desktopStatsHint,
          actionLabel: l.retry,
          onAction: () => ref.invalidate(libraryStatsProvider),
        ),
        null => const Padding(
          padding: EdgeInsets.all(MTSpace.xl),
          child: Center(child: MTSpinner()),
        ),
      },
    );
  }

  Widget _figures(BuildContext context, LibraryStats s) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatsCard(
          title: null,
          child: StatsFigures(
            figures: [
              (value: '${s.count}', label: l.desktopStatsClips),
              (value: mtFormatSize(s.bytes), label: l.desktopStatsRoom),
              // Only when most lengths are known: a total of the few known
              // would read as the whole library's.
              if (s.timed * 2 >= s.count)
                (
                  value: l.desktopStatsHours(s.length.inHours),
                  label: l.desktopStatsLength,
                ),
            ],
          ),
        ),
        const SizedBox(height: MTSpace.xs),
        Text(
          l.desktopStatsHint,
          style: Theme.of(context).textTheme.labelSmall!
              .copyWith(color: p.ink3),
        ),
      ],
    );
  }

  Widget _bySite(BuildContext context, WidgetRef ref, LibraryStats s) {
    final l = context.mtl;
    // By room taken; by count when no size is known at all.
    final sized = s.bySite.any((r) => r.bytes > 0);
    return StatsCard(
      title: l.desktopStatsBySite,
      child: StatsBars(
        rows: [
          for (final r in s.bySite)
            (
              label: platformLabel(l, r.key),
              measure: sized ? r.bytes : r.count,
              value: _countAndSize(l, r.count, r.bytes),
              onTap: () =>
                  _openLibrary(context, ref, (view) => view.setPlatform(r.key)),
            ),
        ],
      ),
    );
  }

  Widget _byChannel(BuildContext context, WidgetRef ref, LibraryStats s) {
    final l = context.mtl;
    return StatsCard(
      title: l.desktopStatsByChannel,
      child: StatsBars(
        rows: [
          for (final r in s.byChannel)
            (
              label: r.key,
              measure: r.count,
              value: _countAndSize(l, r.count, r.bytes),
              onTap: () => _openLibrary(context, ref, (view) {
                if (ref.read(libraryViewProvider).channel != r.key) {
                  view.toggleChannel(r.key);
                }
              }),
            ),
          if (s.otherChannels case final rest?)
            (
              label: l.desktopStatsOtherChannels,
              measure: rest.count,
              value: _countAndSize(l, rest.count, rest.bytes),
              onTap: null,
            ),
        ],
      ),
    );
  }

  Widget _byMonth(BuildContext context, LibraryStats s) {
    final dates = MaterialLocalizations.of(context);
    return StatsCard(
      title: context.mtl.desktopStatsByMonth,
      child: StatsMonths(
        months: [
          for (final r in s.byMonth.take(_months).toList().reversed)
            // The month's name alone: the year is the same for most.
            (
              label: dates.formatMonthYear(r.key).split(' ').first,
              count: r.count,
            ),
        ],
      ),
    );
  }

  List<Widget> _suggestions(BuildContext context, LibraryStats s) {
    final l = context.mtl;
    int room(List<LibraryItem> items) =>
        items.fold(0, (sum, i) => sum + (i.sizeBytes ?? 0));
    Widget list(
      String title,
      String meta,
      List<LibraryItem> items,
      String? Function(LibraryItem) detail,
    ) => StatsCard(
      title: mtMetaLine([title, meta]),
      child: Column(
        children: [
          for (final item in items.take(_listed))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: MTForeignText(item.title, maxLines: 1),
              subtitle: switch (detail(item)) {
                final d? => Text(d),
                null => null,
              },
              onTap: () => showItemDetailsSheet(context, item),
            ),
        ],
      ),
    );
    return [
      if (s.neverPlayed.isNotEmpty)
        list(
          l.desktopStatsNeverPlayed,
          _countAndSize(l, s.neverPlayed.length, room(s.neverPlayed)),
          s.neverPlayed,
          (i) => i.sizeBytes == null ? null : mtFormatSize(i.sizeBytes!),
        ),
      // Only while transcripts are on: off, every clip would be listed.
      if (s.withText > 0 && s.withoutText.isNotEmpty)
        list(
          l.desktopStatsWithoutText,
          l.transcriptsClips(s.withoutText.length),
          s.withoutText,
          (i) => i.timestamp == null ? null : mtTimeAgo(context, i.timestamp!),
        ),
    ];
  }

  /// The library tab, filtered as [filter] sets it.
  void _openLibrary(
    BuildContext context,
    WidgetRef ref,
    void Function(LibraryViewNotifier view) filter,
  ) {
    filter(ref.read(libraryViewProvider.notifier));
    context.go('/');
  }
}

String _countAndSize(MTLocalizations l, int count, int bytes) =>
    mtMetaLine([l.transcriptsClips(count), if (bytes > 0) mtFormatSize(bytes)]);
