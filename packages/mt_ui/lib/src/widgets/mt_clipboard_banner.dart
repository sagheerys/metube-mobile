import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// The "a link is ready in the clipboard" bar, which sits above the mini
/// player.
///
/// Presentation only: every string and action comes from the app, since
/// mt_ui does not know the server exists. **Both actions are offered on
/// purpose**: "download" for the common case and "options" for whoever
/// wants a different quality, because an immediate download with no way
/// out unsettles anyone unsure of the result. "Dismiss" is a condition: a
/// bar that returns after every refusal stops being help and becomes
/// nagging.
class MTClipboardBanner extends StatelessWidget {
  const MTClipboardBanner({
    super.key,
    required this.url,
    required this.title,
    required this.downloadLabel,
    required this.optionsLabel,
    required this.onDownload,
    required this.onOptions,
    required this.onDismiss,
  });

  final String url;
  final String title;
  final String downloadLabel;
  final String optionsLabel;
  final VoidCallback onDownload;
  final VoidCallback onOptions;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Material(
      color: p.accentSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.pagePad, MTSpace.sm, MTSpace.sm, MTSpace.sm),
        child: Row(
          children: [
            Icon(Icons.link_rounded, size: 18, color: p.accentInk),
            const SizedBox(width: MTSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: text.labelMedium!.copyWith(color: p.accentInk)),
                  // The URL is **always LTR** and truncated from the front:
                  // its tail, the
                  // clip id, is what distinguishes it, while its head
                  // `https://www.` is the
                  // same every time.
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: text.labelSmall!.copyWith(color: p.ink3),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onOptions, child: Text(optionsLabel)),
            FilledButton(onPressed: onDownload, child: Text(downloadLabel)),
            IconButton(
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: p.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
