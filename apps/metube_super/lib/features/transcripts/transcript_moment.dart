import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_transcripts/mt_transcripts.dart' show SearchText;
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/library_models.dart';
import '../player/playback_providers.dart';

/// [text] with every word of [query] lit in the action colour, wherever the
/// subtitles spelled it differently from how it was typed.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    required this.query,
    required this.style,
    this.maxLines,
  });

  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final lit = style.copyWith(
      color: p.accentInk,
      backgroundColor: p.accentSoft,
      fontWeight: FontWeight.w700,
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end) in SearchText.matchRanges(text, query)) {
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(text: text.substring(start, end), style: lit));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    final (direction, align) = mtForeignLine(context, text);
    return Text.rich(
      TextSpan(style: style, children: spans),
      textDirection: direction,
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// One moment of a clip: when it was said, and what. Tapping it plays the
/// clip from that second.
class TranscriptMomentRow extends ConsumerWidget {
  const TranscriptMomentRow({
    super.key,
    required this.start,
    required this.text,
    required this.query,
    this.item,
    this.context,
    this.maxLines = 2,
    this.onTap,
    this.current,
  }) : assert(item != null || onTap != null, 'nothing to do on a tap');

  /// Played from [start] on a tap, unless [onTap] says otherwise.
  final LibraryItem? item;
  final Duration start;
  final String text;
  final String query;

  /// The line after, dimmer, so the moment can be judged in place.
  final String? context;
  final int? maxLines;

  /// Replaces playing from here, for a row whose own context will not
  /// outlive the tap (inside a sheet that closes first).
  final VoidCallback? onTap;

  /// In a transcript that follows playback: whether this is the line being
  /// said now. Null outside one, where no line is.
  final bool? current;

  @override
  Widget build(BuildContext buildContext, WidgetRef ref) {
    final text = Theme.of(buildContext).textTheme;
    final p = MTThemeX.of(buildContext).palette;
    final now = current ?? false;
    final body = text.bodySmall!.copyWith(
      color: now ? p.ink : p.ink2,
      fontWeight: now ? FontWeight.w700 : null,
    );
    return InkWell(
      onTap:
          onTap ?? () => playFromMoment(buildContext, ref.read, item!, start),
      child: Container(
        padding: EdgeInsetsDirectional.only(
          top: MTSpace.xs,
          bottom: MTSpace.xs,
          start: current == null ? 0 : MTSpace.sm,
        ),
        // The line being said is marked on the side reading starts from,
        // leaving the lit words their own colour.
        decoration: current == null
            ? null
            : BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(
                    color: now ? p.accent : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A time reads left to right in either language.
            Text(
              mtLtrRun(mtFormatDuration(start)),
              style: body
                  .copyWith(color: p.accent, fontWeight: FontWeight.w700)
                  .tabular,
            ),
            const SizedBox(width: MTSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HighlightedText(
                    this.text,
                    query: query,
                    style: body,
                    maxLines: maxLines,
                  ),
                  // Lit too: a phrase the captions split ends on this line.
                  if (context case final next?)
                    HighlightedText(
                      next,
                      query: query,
                      maxLines: 1,
                      style: body.copyWith(color: p.ink3),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plays [item] from [start]: the moment the words were said.
///
/// Video goes through the saved position, which the video player already
/// resumes from on open, so no second way of starting mid-clip is added.
/// Audio seeks once loaded, because the audio player resumes only long
/// items on its own.
///
/// Takes a reader rather than a widget's ref: a sheet that closed before
/// playing has no live ref left, while the screen's container outlives it.
Future<void> playFromMoment(
  BuildContext context,
  T Function<T>(ProviderListenable<T> provider) read,
  LibraryItem item,
  Duration start,
) async {
  final entry = toPlaylistItem(item);
  if (item.isAudio) {
    final handler = read(audioHandlerProvider);
    await handler.playItems([entry], startIndex: 0);
    await handler.seek(start);
    return;
  }
  // A moment in the first seconds clears any older position instead, so
  // the clip starts from the top rather than where it was last left.
  await read(playbackPositionsProvider).save(item.canonicalUrl, start);
  read(playbackRequestProvider.notifier).state = PlaybackRequest(
    items: [entry],
    startIndex: 0,
  );
  if (context.mounted) await context.push('/player');
}
