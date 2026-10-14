import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'mt_captions.dart';
import 'video_buttons.dart';

/// The subtitles' buttons in the top bar: the language, while the subtitles
/// show and the clip has more than one, then CC.
class MTCaptionButtons extends StatelessWidget {
  const MTCaptionButtons({super.key, required this.captions});

  final MTCaptions captions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return ListenableBuilder(
      listenable: Listenable.merge([captions.shown, captions.language]),
      builder: (context, _) {
        final shown = captions.shown.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shown && captions.switchable) ...[
              _LanguageButton(captions: captions),
              const SizedBox(width: MTSpace.xs),
            ],
            MTVideoIconButton(
              icon: shown
                  ? Icons.closed_caption_rounded
                  : Icons.closed_caption_off_rounded,
              onTap: () => captions.shown.value = !shown,
              tooltip: shown ? l10n.subtitlesHide : l10n.subtitlesShow,
              active: shown,
            ),
          ],
        );
      },
    );
  }
}

/// The language on screen as its short code; a tap moves to the next.
class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.captions});

  final MTCaptions captions;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.mtl.subtitlesLanguage,
    child: Material(
      color: Colors.black.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(MTRadius.field - 1),
      child: InkWell(
        onTap: captions.nextLanguage,
        borderRadius: BorderRadius.circular(MTRadius.field - 1),
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MTSpace.sm),
            child: Center(
              child: Text(
                (captions.current ?? '').split('-').first.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: MTPalette.serverCardInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
