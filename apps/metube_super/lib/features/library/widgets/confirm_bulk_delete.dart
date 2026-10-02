import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shared/error_report.dart';
import '../library_actions.dart';
import '../library_providers.dart';

/// Bulk delete confirmation: deletes from the server by canonical URL,
/// the one key every list agrees on.
void confirmBulkDelete(
  BuildContext context,
  WidgetRef ref,
  Set<String> selection,
) {
  final l10n = context.mtl;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(l10n.deleteMultipleConfirm(selection.length)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            final actions = ref.read(libraryActionsProvider);
            try {
              await actions.deleteFromServer(selection.toList());
              ref.read(libraryViewProvider.notifier).clearSelection();
              if (context.mounted) {
                showMTSnack(
                  context,
                  l10n.deletedFromServer,
                  type: MTSnackType.success,
                );
              }
            } catch (e) {
              if (context.mounted) {
                showErrorSnack(context, ref, e, tag: 'library');
              }
            }
          },
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
}
