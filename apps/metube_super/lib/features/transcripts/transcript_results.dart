import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart' show UrlKit;
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import '../library/library_models.dart';
import '../library/library_providers.dart';
import 'transcript_moment.dart';
import 'transcript_openers.dart';
import 'transcripts_state.dart';

/// The clips in which the library's search words were **said**, with the
/// moments they were said at. Empty while the feature is off.
final transcriptResultsProvider = Provider<List<(LibraryItem, ClipHits)>>((
  ref,
) {
  final enabled = ref.watch(transcriptsEnabledProvider).valueOrNull ?? false;
  final query = ref.watch(libraryViewProvider.select((o) => o.query));
  ref.watch(transcriptsRevisionProvider);
  final index = ref.watch(transcriptIndexProvider).valueOrNull;
  final library = ref.watch(libraryItemsProvider).valueOrNull;
  if (!enabled || index == null || library == null) return const [];

  final items = _ItemLookup(library);
  return [
    for (final clip in index.search(
      query,
      perClip: TranscriptResultsSliver.maxMoments,
    ))
      if (items.find(clip.canonicalUrl) case final item?) (item, clip),
  ].take(TranscriptResultsSliver.maxClips).toList();
});

/// How many clips a library search found, by title or by what was said in
/// them, each counted once: counting titles alone read "no results" above
/// a list of clips.
final libraryResultCountProvider = Provider<int>(
  (ref) => {
    for (final item
        in ref.watch(visibleLibraryProvider).valueOrNull ?? const [])
      item.canonicalUrl,
    for (final (item, _) in ref.watch(transcriptResultsProvider))
      item.canonicalUrl,
  }.length,
);

/// Below the library's title matches: the clips in which the searched
/// words were said, each with the moments they were said at.
class TranscriptResultsSliver extends ConsumerWidget {
  const TranscriptResultsSliver({super.key});

  /// Enough to scan on a phone; a query this common is better narrowed.
  static const maxClips = 20;

  /// Moments shown per clip. The rest are one tap away inside the clip.
  static const maxMoments = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(transcriptResultsProvider);
    if (results.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
      sliver: SliverList.list(
        children: [
          const SizedBox(height: MTSpace.lg),
          MTSectionHeader(title: context.mtl.transcriptsSaidInside),
          for (final (item, clip) in results)
            _ClipMoments(item: item, clip: clip),
        ],
      ),
    );
  }
}

/// Library items by URL, and by YouTube id as a fallback: the transcript
/// is filed under the URL its subtitles came back with, and the clip under
/// the one its download did.
class _ItemLookup {
  _ItemLookup(List<LibraryItem> items)
    : _byUrl = {for (final i in items) i.canonicalUrl: i},
      _byId = {
        for (final i in items) ?UrlKit.youtubeVideoId(i.canonicalUrl): i,
      };

  final Map<String, LibraryItem> _byUrl;
  final Map<String, LibraryItem> _byId;

  LibraryItem? find(String url) =>
      _byUrl[url] ??
      switch (UrlKit.youtubeVideoId(url)) {
        final id? => _byId[id],
        null => null,
      };
}

class _ClipMoments extends ConsumerWidget {
  const _ClipMoments({required this.item, required this.clip});

  final LibraryItem item;
  final ClipHits clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final p = MTThemeX.of(context).palette;
    final query = ref.watch(libraryViewProvider.select((o) => o.query));
    void openAll() => showTranscriptSheet(context, item, query);
    final (titleDirection, titleAlign) = mtForeignLine(context, item.title);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: MTSpace.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The title opens the whole transcript: the moments listed here
          // are the closest few, not all of them.
          InkWell(
            onTap: openAll,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    textDirection: titleDirection,
                    textAlign: titleAlign,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.subject_rounded,
                  size: 18,
                  color: p.ink3,
                  semanticLabel: l10n.transcriptFull,
                ),
              ],
            ),
          ),
          for (final hit in clip.hits)
            TranscriptMomentRow(
              item: item,
              start: hit.start,
              text: hit.text,
              context: hit.next,
              query: query,
            ),
          if (clip.total > clip.hits.length)
            TextButton(
              onPressed: openAll,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                l10n.transcriptSaidMore(clip.total - clip.hits.length),
              ),
            ),
        ],
      ),
    );
  }
}
