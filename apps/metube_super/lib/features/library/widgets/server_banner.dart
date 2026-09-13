import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';
import '../../shared/error_text.dart';
import '../library_providers.dart';

/// **The library stays; this line says why the server part is missing**
/// (field report 2026-09-13).
///
/// With no internet the library used to become a full-screen "connection
/// failed" even though every offline copy could still play. Now the phone's
/// files stay on screen, and this banner states the cause, says the saved
/// videos still play, and offers a retry. It shows only while there is a
/// library to show beneath it: with nothing on the phone the full-screen
/// error remains, because a banner above an empty screen explains nothing.
///
/// Olive is Super's "offline" colour, from the palette like everything else,
/// so night mode and Lite's identity need nothing of their own here.
class LibraryServerBanner extends ConsumerWidget {
  const LibraryServerBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(libraryServerErrorProvider);
    final hasLibrary = ref.watch(libraryItemsProvider).hasValue;
    if (error == null || !hasLibrary) return const SizedBox.shrink();

    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.sm),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          MTSpace.md,
          MTSpace.sm,
          MTSpace.md,
          0,
        ),
        decoration: BoxDecoration(
          color: p.offlineSoft,
          borderRadius: BorderRadius.circular(MTRadius.card),
          border: Border.all(color: p.offline.withValues(alpha: 0.35)),
        ),
        // **The retry sits under the text, not beside it** (device matrix,
        // 320x534 at 1.3x): beside it, the button kept its full width and
        // the row overflowed by 36 points, leaving the text no room at all.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: MTSpace.xs / 2),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 20,
                color: p.offlineInk,
              ),
            ),
            const SizedBox(width: MTSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    errorText(l10n, error),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.offlineInk,
                    ),
                  ),
                  Text(
                    l10n.serverUnreachableLocalHint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(color: p.offlineInk),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => ref.invalidate(historyProvider),
                      style: TextButton.styleFrom(
                        foregroundColor: p.offlineInk,
                      ),
                      child: Text(l10n.retry),
                    ),
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
