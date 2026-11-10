import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../downloads_library/library_providers.dart';
import '../playlists/playlists_providers.dart';

/// **Read through the system picker (SAF):** Android 11+ refuses to read
/// a file the app did not create, even in the same folder (`errno 13`),
/// and a migration backup comes from another device by definition. The
/// app's own backups become such files too once it is reinstalled: Android
/// drops their owner, and the app can no longer list them.
Future<String?> pickBackupContents() async {
  final picked = await FilePicker.platform.pickFiles(withData: true);
  final file = picked?.files.singleOrNull;
  if (file == null) return null;
  if (file.bytes case final Uint8List bytes) return utf8.decode(bytes);
  final path = file.path;
  return path == null ? null : File(path).readAsString();
}

/// Offered once, on a phone that has Lite downloads but no server: what a
/// reinstall leaves behind when Google's own backup did not bring the
/// settings back. A phone with no downloads is a first install, and is
/// left alone.
///
/// **Why the user picks the file**: the newest copy in the backups folder
/// cannot be found by the app after a reinstall (measured on Android 16,
/// 2026-11-10: every copy there had lost its owner), but the system picker
/// reaches it because the user chooses it.
Future<void> maybeOfferPickedRestore(
  BuildContext context,
  WidgetRef ref,
  KeyValueStore store,
) async {
  final List<Object> items;
  try {
    items = await ref.read(localMediaProvider.future);
  } on Object {
    return;
  }
  // Asked again on a later start: the media permission may not be granted
  // yet, and without it the downloads are not seen.
  if (items.isEmpty || !context.mounted) return;
  await ref
      .read(prefsMutexProvider)
      .run(() => store.setBool('auto_restore_offered', true));
  if (!context.mounted) return;
  final l10n = context.mtl;
  final choose = await showMTConfirm(
    context,
    title: l10n.restorePickTitle,
    message: l10n.restorePickBody,
    confirmLabel: l10n.restorePickChoose,
    cancelLabel: l10n.cancel,
  );
  if (!choose) return;
  try {
    final contents = await pickBackupContents();
    if (contents == null) return;
    await ref.read(backupServiceProvider).importFromString(contents);
    await ref.read(settingsProvider.notifier).reloadFromStore();
    ref.invalidate(localMediaProvider);
    ref.invalidate(playlistsProvider);
    if (context.mounted) {
      showMTSnack(context, l10n.autoRestoreSuccess, type: MTSnackType.success);
    }
  } on Object {
    if (context.mounted) {
      showMTSnack(context, l10n.restoreFailed, type: MTSnackType.error);
    }
  }
}
