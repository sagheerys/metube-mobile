import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'subtitles.dart';

/// The subtitles' size and background, as two rows of choices. Shared by
/// settings and the sheet a long press on CC opens over the picture.
class SubtitleStyleChoices extends StatelessWidget {
  const SubtitleStyleChoices({super.key, required this.prefs});

  final SubtitlePrefs prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([prefs.size, prefs.background]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.subtitlesSize, style: text.bodyMedium),
          const SizedBox(height: MTSpace.xs),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(l10n.subtitlesSizeSmall)),
              ButtonSegment(value: 1, label: Text(l10n.subtitlesSizeMedium)),
              ButtonSegment(value: 2, label: Text(l10n.subtitlesSizeLarge)),
            ],
            selected: {prefs.size.value},
            onSelectionChanged: (selection) =>
                prefs.size.value = selection.first,
          ),
          const SizedBox(height: MTSpace.lg),
          Text(l10n.subtitlesBackground, style: text.bodyMedium),
          const SizedBox(height: MTSpace.xs),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(l10n.subtitlesBackgroundSolid),
              ),
              ButtonSegment(
                value: 1,
                label: Text(l10n.subtitlesBackgroundFaint),
              ),
              ButtonSegment(
                value: 2,
                label: Text(l10n.subtitlesBackgroundNone),
              ),
            ],
            selected: {prefs.background.value},
            onSelectionChanged: (selection) =>
                prefs.background.value = selection.first,
          ),
          const SizedBox(height: MTSpace.xs),
          Text(l10n.subtitlesBackgroundHelp, style: text.bodySmall),
        ],
      ),
    );
  }
}

/// The size and background over the playing clip (a long press on CC):
/// each choice shows on the picture at once, without leaving for settings.
Future<void> showSubtitleStyleSheet(
  BuildContext context,
  SubtitlePrefs prefs,
) => showMTSheet<void>(
  context: context,
  useRootNavigator: true,
  builder: (sheet) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      MTSpace.xl,
      MTSpace.lg,
      MTSpace.xl,
      mtSheetBottomPad(sheet, MTSpace.xxl),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(sheet.mtl.subtitles, style: Theme.of(sheet).textTheme.titleMedium),
        const SizedBox(height: MTSpace.lg),
        SubtitleStyleChoices(prefs: prefs),
      ],
    ),
  ),
);
