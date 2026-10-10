import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';

/// **The one failure where nothing is wrong with the app** (audit
/// 2026-09-19): `DELETE_FILE_ON_TRASHCAN` is off by default in MeTube, so
/// the cleanup removes the history row and leaves the file on disk. Lite
/// reports success, the library is right, and the server fills up for
/// months before anyone looks.
///
/// [TrashcanProbe] notices it after a real cleanup — one range request for
/// a file that should be gone — and this is where it is said. It appears
/// only while the condition holds: fixing the container clears it.
class ServerKeepsFilesNotice extends ConsumerWidget {
  const ServerKeepsFilesNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keeps = ref.watch(serverKeepsFilesProvider).valueOrNull ?? false;
    if (!keeps) return const SizedBox.shrink();
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: MTSpace.md),
      child: Container(
        padding: const EdgeInsets.all(MTSpace.md),
        decoration: BoxDecoration(
          color: p.cardAlt,
          borderRadius: BorderRadius.circular(MTRadius.card),
          border: Border.all(color: p.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.folder_off_outlined, color: p.err),
            const SizedBox(width: MTSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.serverKeepsFilesTitle,
                    style: text.bodyMedium!.copyWith(
                      color: p.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: MTSpace.xs),
                  Text(
                    l10n.serverKeepsFilesBody,
                    style: text.bodySmall!.copyWith(color: p.ink2),
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
