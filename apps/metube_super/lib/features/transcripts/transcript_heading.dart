import 'package:flutter/material.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

/// The top of a transcript: its title, the match count with arrows to
/// step between matches, the languages, and a search field that stays
/// folded away until asked for.
///
/// **One search on screen at a time** (field report 2026-09-30): opened
/// from the library's results, a second field repeating the library's own
/// words sat right under it and read as two searches. The words searched
/// for now show as a count with arrows; a field appears only on request.
class TranscriptHeading extends StatelessWidget {
  const TranscriptHeading({
    super.key,
    required this.title,
    required this.transcripts,
    required this.shown,
    required this.query,
    required this.matchCount,
    required this.searching,
    required this.field,
    required this.onSearchToggle,
    required this.onQueryChanged,
    required this.onStep,
    required this.onShow,
    this.onClose,
  });

  final String title;
  final List<Transcript> transcripts;
  final Transcript shown;
  final String query;
  final int matchCount;
  final bool searching;
  final TextEditingController field;
  final VoidCallback onSearchToggle;
  final VoidCallback onQueryChanged;

  /// Moves to the next match (1) or the one before (-1).
  final void Function(int step) onStep;
  final void Function(Transcript transcript) onShow;

  /// Shown as a close button when the transcript sits in a panel rather
  /// than a sheet, which has no edge to drag down.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final p = MTThemeX.of(context).palette;
    final (titleDirection, titleAlign) = mtForeignLine(context, title);
    final hasQuery = query.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                textDirection: titleDirection,
                textAlign: titleAlign,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium,
              ),
            ),
            IconButton(
              onPressed: onSearchToggle,
              tooltip: l10n.transcriptFind,
              isSelected: searching,
              icon: Icon(Icons.search_rounded, color: p.ink2),
              selectedIcon: Icon(Icons.search_off_rounded, color: p.accent),
            ),
            if (onClose case final close?)
              IconButton(
                onPressed: close,
                tooltip: l10n.dismiss,
                icon: Icon(Icons.close_rounded, color: p.ink2),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                mtMetaLine([
                  l10n.transcriptFull,
                  if (hasQuery) l10n.transcriptMatches(matchCount),
                ]),
                style: text.bodySmall!.copyWith(color: p.ink3),
              ),
            ),
            if (hasQuery && matchCount > 0) ...[
              IconButton(
                onPressed: () => onStep(-1),
                tooltip: l10n.transcriptPreviousMatch,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.keyboard_arrow_up_rounded, color: p.accent),
              ),
              IconButton(
                onPressed: () => onStep(1),
                tooltip: l10n.transcriptNextMatch,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: p.accent),
              ),
            ],
          ],
        ),
        if (searching) ...[
          const SizedBox(height: MTSpace.xs),
          MTSearchField(
            hint: l10n.transcriptFind,
            controller: field,
            autofocus: true,
            onChanged: (_) => onQueryChanged(),
          ),
        ],
        if (transcripts.length > 1) ...[
          const SizedBox(height: MTSpace.sm),
          SegmentedButton<Transcript>(
            showSelectedIcon: false,
            segments: [
              for (final t in transcripts)
                ButtonSegment(
                  value: t,
                  label: Text(mtLanguageName(t.language)),
                ),
            ],
            selected: {shown},
            onSelectionChanged: (choice) => onShow(choice.first),
          ),
        ],
      ],
    );
  }
}
