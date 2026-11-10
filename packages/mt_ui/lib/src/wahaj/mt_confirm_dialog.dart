import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import '../widgets/mt_desktop_app.dart';
import '../widgets/mt_route_motion.dart';

/// Each platform's own scale: the phones share this dialog with the
/// computer since the mobile plan of 2026-11-01.
MTCorners _cornersOf(BuildContext context) =>
    MTDesktopApp.isDesktop(context) ? MTCorners.desktop : MTCorners.mobile;

/// The Wahaj confirmation: a light card with the heading in Kufi, and
/// **the clip itself shown before anything is deleted**, so nobody removes
/// the wrong item from a list of look-alike titles.
///
/// A destructive confirm is drawn in the error colour with an outline; the
/// cancel stays quiet. Resolves true only when confirmed.
Future<bool> showMTConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  Widget? preview,
}) async =>
    await showMTDialog<bool>(
      context: context,
      builder: (_) => MTConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        preview: preview,
      ),
    ) ??
    false;

class MTConfirmDialog extends StatelessWidget {
  const MTConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.destructive = false,
    this.preview,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  /// What the action applies to, usually an [MTDialogClip].
  final Widget? preview;

  static const _maxWidth = 380.0;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final corners = _cornersOf(context);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(corners.field),
    );
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scrolls when it cannot fit (the largest text on a small
            // phone), so the buttons below always stay on screen.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MTSpace.pagePad,
                  MTSpace.pagePad,
                  MTSpace.pagePad,
                  MTSpace.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleLarge),
                    const SizedBox(height: MTSpace.xs),
                    Text(
                      message,
                      style: text.bodyMedium!.copyWith(color: p.ink2),
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: MTSpace.md),
                      preview!,
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: p.line),
            Padding(
              padding: const EdgeInsets.all(MTSpace.sm),
              // Wraps rather than overflows: two long labels ("Forget this
              // device", a large text size) take a second line.
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: MTSpace.xs,
                runSpacing: MTSpace.xs,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: p.ink2,
                      shape: buttonShape,
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(cancelLabel),
                  ),
                  if (destructive)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.err,
                        side: BorderSide(
                          color: p.err.withValues(alpha: 0.45),
                          width: 1.4,
                        ),
                        textStyle: text.labelLarge,
                        shape: buttonShape,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(confirmLabel),
                    )
                  else
                    FilledButton(
                      style: FilledButton.styleFrom(shape: buttonShape),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(confirmLabel),
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

/// The clip a dialog acts on: its cover and its title, on a tinted strip.
class MTDialogClip extends StatelessWidget {
  const MTDialogClip({super.key, required this.title, this.thumbnail});

  final String title;

  /// Usually the clip's cover, sized by this strip.
  final Widget? thumbnail;

  static const _thumb = Size(44, 28);

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final corners = _cornersOf(context);
    return Container(
      padding: const EdgeInsets.all(MTSpace.xs),
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(corners.thumb),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(corners.box),
            child: SizedBox.fromSize(
              size: _thumb,
              child: thumbnail ?? ColoredBox(color: p.accentSoft),
            ),
          ),
          const SizedBox(width: MTSpace.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall!
                  .copyWith(color: p.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
