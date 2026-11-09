import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/library_data.dart';
import '../../data/transcripts_data.dart';
import '../../di.dart';
import '../../router.dart';
import '../../shell/section_header.dart';
import '../library/platform_label.dart';
import 'stats_bars.dart';

/// The library counted: from its items, the transcripts on this computer
/// and whether each clip was ever played here.
final libraryStatsProvider = FutureProvider<LibraryStats>((ref) async {
  final items = await ref.watch(libraryItemsProvider.future);
  final index = await ref.watch(transcriptIndexProvider.future);
  final positions = PlaybackPositionStore(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  );
  final played = <String>{
    for (final item in items)
      if (await positions.stampOf(item.canonicalUrl) != null) item.canonicalUrl,
  };
  return statsOf(items, hasText: index.contains, played: played.contains);
});

/// **Library statistics**: how many clips, how much room and how many
/// hours, by site, channel and month, and what may deserve a look. It
/// suggests and never deletes: a clip opens its page, where the user
/// decides.
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  /// Wide enough for two columns of breakdowns side by side.
  static const double _twoColumns = 1000;

  /// How many clips each suggestion lists.
  static const _listed = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final stats = ref.watch(libraryStatsProvider);
    // **The last figures stay while new ones are counted.** The library
    // refreshes every few seconds, and a page swapped for a spinner each
    // time lost its scroll position.
    return switch (stats.valueOrNull) {
      final value? when value.count > 0 => LayoutBuilder(
        builder: (context, box) {
          final left = [_bySite(context, value), _byMonth(context, value)];
          final right = [
            // A history that names no channel would give one bar of all.
            if (value.byChannel.isNotEmpty) _byChannel(context, value),
            _suggestions(context, value),
          ];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(MTSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Heading(stats: value),
                const SizedBox(height: MTSpace.xl),
                if (box.maxWidth >= _twoColumns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: left)),
                      const SizedBox(width: MTSpace.xxl),
                      Expanded(child: Column(children: right)),
                    ],
                  )
                else
                  Column(children: [...left, ...right]),
              ],
            ),
          );
        },
      ),
      _? => Center(
        child: MTEmptyFrame(
          title: l.noVideosFound,
          message: l.desktopEmptyLibraryMessage,
        ),
      ),
      null when stats.hasError => Center(
        child: MTEmptyFrame(
          title: l.serverStatusOffline,
          message: l.desktopServerPartMissing,
          actionLabel: l.retry,
          onAction: () => ref.invalidate(libraryStatsProvider),
        ),
      ),
      null => const Center(child: MTSpinner()),
    };
  }

  Widget _bySite(BuildContext context, LibraryStats stats) {
    final l = context.mtl;
    // By room taken; by count when no size is known at all.
    final sized = stats.bySite.any((r) => r.bytes > 0);
    return _Section(
      title: l.desktopStatsBySite,
      child: StatsBars(
        rows: [
          for (final r in stats.bySite)
            (
              label: platformLabel(l, r.key),
              measure: sized ? r.bytes : r.count,
              value: _countAndSize(l, r.count, r.bytes),
            ),
        ],
      ),
    );
  }

  Widget _byChannel(BuildContext context, LibraryStats stats) {
    final l = context.mtl;
    return _Section(
      title: l.desktopStatsByChannel,
      child: StatsBars(
        rows: [
          for (final r in stats.byChannel)
            (
              label: r.key,
              measure: r.count,
              value: _countAndSize(l, r.count, r.bytes),
            ),
          if (stats.otherChannels case final rest?)
            (
              label: l.desktopStatsOtherChannels,
              measure: rest.count,
              value: _countAndSize(l, rest.count, rest.bytes),
            ),
          if (stats.unnamed > 0)
            (
              label: l.desktopStatsUnnamed,
              measure: stats.unnamed,
              value: l.transcriptsClips(stats.unnamed),
            ),
        ],
      ),
    );
  }

  Widget _byMonth(BuildContext context, LibraryStats stats) {
    final l = context.mtl;
    final dates = MaterialLocalizations.of(context);
    return _Section(
      title: l.desktopStatsByMonth,
      child: StatsBars(
        rows: [
          for (final r in stats.byMonth)
            (
              label: westernDigits(dates.formatMonthYear(r.key)),
              measure: r.count,
              value: _countAndSize(l, r.count, r.bytes),
            ),
        ],
      ),
    );
  }

  Widget _suggestions(BuildContext context, LibraryStats stats) {
    final l = context.mtl;
    int room(List<LibraryItem> items) =>
        items.fold(0, (sum, i) => sum + (i.sizeBytes ?? 0));
    return _Section(
      title: l.desktopStatsWorthALook,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stats.neverPlayed.isNotEmpty)
            StatsSuggestion(
              title: l.desktopStatsNeverPlayed,
              meta: _countAndSize(
                l,
                stats.neverPlayed.length,
                room(stats.neverPlayed),
              ),
              lead: l.desktopStatsLargest,
              items: stats.neverPlayed.take(_listed).toList(),
              detail: (i) =>
                  i.sizeBytes == null ? null : mtFormatSize(i.sizeBytes!),
              onOpen: (i) => _open(context, i),
            ),
          if (stats.withoutText.isNotEmpty)
            StatsSuggestion(
              title: l.desktopStatsWithoutText,
              meta: l.transcriptsClips(stats.withoutText.length),
              lead: l.desktopStatsNewest,
              items: stats.withoutText.take(_listed).toList(),
              detail: (i) =>
                  i.timestamp == null ? null : mtTimeAgo(context, i.timestamp!),
              onOpen: (i) => _open(context, i),
            ),
        ],
      ),
    );
  }

  void _open(BuildContext context, LibraryItem item) =>
      GoRouter.of(context).go(EmberRoutes.item(item.canonicalUrl));
}

String _countAndSize(MTLocalizations l, int count, int bytes) =>
    mtMetaLine([l.transcriptsClips(count), if (bytes > 0) mtFormatSize(bytes)]);

/// Arabic-Indic digits as the rest of the app writes digits.
String westernDigits(String text) => text.replaceAllMapped(
  RegExp('[٠-٩]'),
  (m) => '${m[0]!.codeUnitAt(0) - 0x0660}',
);

/// The title, what the page is for, and the library in five figures.
class _Heading extends StatelessWidget {
  const _Heading({required this.stats});

  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final share = (stats.withText * 100 / stats.count).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.desktopStats, style: text.headlineSmall),
        const SizedBox(height: MTSpace.xxs),
        Text(
          l.desktopStatsHint,
          style: text.bodySmall?.copyWith(color: p.ink3),
        ),
        const SizedBox(height: MTSpace.lg),
        StatsFigures(
          figures: [
            StatsTile(value: '${stats.count}', label: l.desktopStatsClips),
            StatsTile(
              value: mtFormatSize(stats.bytes),
              label: l.desktopStatsRoom,
            ),
            // Only when most lengths are known: a total of the few known
            // would read as the library's.
            if (stats.timed * 2 >= stats.count)
              StatsTile(
                value: l.desktopStatsHours(stats.length.inHours),
                label: l.desktopStatsLength,
              ),
            StatsTile(
              value: mtLtrRun('$share%'),
              label: l.desktopStatsWithText,
            ),
            StatsTile(
              value: '${stats.neverPlayed.length}',
              label: l.desktopStatsNeverPlayed,
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MTSpace.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EmberSectionHeader(title: title),
        const SizedBox(height: MTSpace.md),
        child,
      ],
    ),
  );
}
