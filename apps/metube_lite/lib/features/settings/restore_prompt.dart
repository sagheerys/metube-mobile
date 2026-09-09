import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../downloads_library/library_providers.dart';
import '../playlists/playlists_providers.dart';
import 'auto_backup.dart';

/// Rule 1, step 4 (Lite): on the first launch after a reinstall, if an
/// automatic backup is found on disk, it offers "restore your previous
/// data?".
///
/// It is offered once only (the `auto_restore_offered` key), so it does not
/// follow the user at every launch after they decline.
Future<void> maybeOfferAutoRestore(BuildContext context, WidgetRef ref) async {
  final store = ref.read(keyValueStoreProvider);
  if (await store.getBool('auto_restore_offered') ?? false) return;
  // A fresh install only: a configured server means this is not a clean
  // start, and offering to restore a backup the app itself just wrote is
  // noise with no benefit.
  if (ref.read(settingsProvider).isConfigured) return;

  final backup = ref.read(autoBackupProvider);
  // **The newest copy from the rotation** (decision 2026-09-04): it used to
  // be a single copy in a fixed file, and it could be **orphaned**, because
  // its key died with the reinstall. The copies are plain text now, so none
  // can be orphaned, and dated, so an older one can be reached from the
  // backup screen if the newest is the problem.
  final latest = await backup.latest();
  if (latest == null) return;

  await ref
      .read(prefsMutexProvider)
      .run(() => store.setBool('auto_restore_offered', true));
  if (!context.mounted) return;

  final l10n = context.mtl;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.restoreSettings),
      content: Text(l10n.restoreConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.restoreData),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;

  try {
    await backup.restore(latest);
    await ref.read(settingsProvider.notifier).reloadFromStore();
    ref.invalidate(localMediaProvider);
    ref.invalidate(playlistsProvider);
    if (context.mounted) {
      showMTSnack(context, l10n.autoRestoreSuccess, type: MTSnackType.success);
    }
  } catch (_) {
    if (context.mounted) {
      showMTSnack(context, l10n.restoreFailed, type: MTSnackType.error);
    }
  }
}
