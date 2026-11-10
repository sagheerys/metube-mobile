import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'subtitles.dart';

/// The subtitles' size and background, as two rows of choices. Shared by
/// settings and the sheet a long press on CC opens over the picture.
class SubtitleStyleChoices extends StatelessWidget {
  const SubtitleStyleChoices({
    super.key,
    required this.prefs,
    this.compact = false,
  });

  final SubtitlePrefs prefs;

  /// Each label beside its row and no note: the panel over a landscape
  /// picture has to leave the subtitle line below it in view.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: Listenable.merge([prefs.size, prefs.background]),
      builder: (context, _) {
        final size = SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(l10n.subtitlesSizeSmall)),
            ButtonSegment(value: 1, label: Text(l10n.subtitlesSizeMedium)),
            ButtonSegment(value: 2, label: Text(l10n.subtitlesSizeLarge)),
          ],
          selected: {prefs.size.value},
          onSelectionChanged: (selection) => prefs.size.value = selection.first,
        );
        final background = SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(l10n.subtitlesBackgroundSolid)),
            ButtonSegment(value: 1, label: Text(l10n.subtitlesBackgroundFaint)),
            ButtonSegment(value: 2, label: Text(l10n.subtitlesBackgroundNone)),
          ],
          selected: {prefs.background.value},
          onSelectionChanged: (selection) =>
              prefs.background.value = selection.first,
        );
        if (compact) {
          TableRow row(String label, Widget choices) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: MTSpace.lg),
                child: Text(label, style: text.bodyMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: MTSpace.xxs),
                child: choices,
              ),
            ],
          );
          return Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              row(l10n.subtitlesSize, size),
              row(l10n.subtitlesBackground, background),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.subtitlesSize, style: text.bodyMedium),
            const SizedBox(height: MTSpace.xs),
            size,
            const SizedBox(height: MTSpace.lg),
            Text(l10n.subtitlesBackground, style: text.bodyMedium),
            const SizedBox(height: MTSpace.xs),
            background,
            const SizedBox(height: MTSpace.xs),
            Text(l10n.subtitlesBackgroundHelp, style: text.bodySmall),
          ],
        );
      },
    );
  }
}

/// The size and background over the playing clip (a long press on CC):
/// each choice shows on the picture at once, without leaving for settings.
///
/// Upright, the picture sits above a sheet. On its side the picture fills
/// the screen and a sheet would cover the very line being adjusted, so the
/// choices open as a panel along the top instead, over a picture left
/// undimmed so the background reads as it will look.
Future<void> showSubtitleStyleSheet(BuildContext context, SubtitlePrefs prefs) {
  final screen = MediaQuery.sizeOf(context);
  if (screen.width > screen.height) return _showOverPicture(context, prefs);
  return showMTSheet<void>(
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
          Text(
            sheet.mtl.subtitles,
            style: Theme.of(sheet).textTheme.titleMedium,
          ),
          const SizedBox(height: MTSpace.lg),
          SubtitleStyleChoices(prefs: prefs),
        ],
      ),
    ),
  );
}

/// The widest the landscape panel grows: two rows of three choices read
/// at a glance without stretching across the whole picture.
const double _panelWidth = 560;

Future<void> _showOverPicture(BuildContext context, SubtitlePrefs prefs) {
  final still = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: still ? Duration.zero : MTMotion.reveal,
    pageBuilder: (panel, _, _) {
      final p = MTThemeX.of(panel).palette;
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(MTSpace.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _panelWidth),
              child: Material(
                key: const ValueKey('subtitle-style-panel'),
                color: p.card,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MTRadius.sheet),
                  side: BorderSide(color: p.line),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(MTSpace.lg),
                  child: SubtitleStyleChoices(prefs: prefs, compact: true),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: MTMotion.entrance),
      child: child,
    ),
  );
}
