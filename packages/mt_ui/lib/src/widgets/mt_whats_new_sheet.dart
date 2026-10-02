import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_markdown_text.dart';
import 'mt_system_bars.dart';

/// "What's new", shown once after an update. [notes] is already in the
/// reader's language; when empty, the sheet says the notes are on the
/// release page, which [onOpenPage] opens.
void showMTWhatsNewSheet(
  BuildContext context, {
  required String version,
  required String notes,
  required VoidCallback onOpenPage,
}) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        MTWhatsNewSheet(version: version, notes: notes, onOpenPage: onOpenPage),
  );
}

class MTWhatsNewSheet extends StatelessWidget {
  const MTWhatsNewSheet({
    super.key,
    required this.version,
    required this.notes,
    required this.onOpenPage,
  });

  final String version;
  final String notes;
  final VoidCallback onOpenPage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final body = notes.trim();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          MTSpace.xl,
          MTSpace.lg,
          MTSpace.xl,
          mtSheetBottomPad(context, MTSpace.xxl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The notes scroll and the buttons stay in sight, as in the
            // update sheet: long notes at a large text size must not push
            // "got it" off the screen.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: p.accent),
                        const SizedBox(width: MTSpace.sm),
                        Expanded(
                          child: Text(
                            l10n.whatsNewTitle(version),
                            style: text.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MTSpace.md),
                    if (body.isEmpty)
                      Text(
                        l10n.whatsNewUnavailable,
                        style: text.bodyMedium!.copyWith(color: p.ink2),
                      )
                    else
                      MTMarkdownText(
                        source: body,
                        style: text.bodySmall!.copyWith(color: p.ink2),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: MTSpace.xl),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: MTSpace.sm,
              children: [
                TextButton(
                  onPressed: onOpenPage,
                  child: Text(l10n.whatsNewReleasePage),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.whatsNewGotIt),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
