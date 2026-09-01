import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../downloads_library/library_providers.dart';
import '../playlists/playlists_providers.dart';
import 'auto_backup.dart';

/// ر-1 خطوة 4 (Lite): أول إطلاق بعد إعادة التثبيت — إن وُجدت نسخة
/// تلقائية على القرص تُعرض «استعادة بياناتك السابقة؟».
///
/// يُعرض مرة واحدة فقط (مفتاح `auto_restore_offered`) كي لا يلاحق
/// المستخدم في كل إقلاع بعد رفضه.
Future<void> maybeOfferAutoRestore(BuildContext context, WidgetRef ref) async {
  final store = ref.read(keyValueStoreProvider);
  if (await store.getBool('auto_restore_offered') ?? false) return;
  // تثبيت جديد فقط: وجود سيرفر مهيأ يعني أن هذه ليست بداية نظيفة —
  // عرض استعادة نسخةٍ كتبها التطبيق نفسه للتو ضجيج لا فائدة فيه.
  if (ref.read(settingsProvider).isConfigured) return;

  final backup = ref.read(autoBackupProvider);
  final state = await backup.inspect();
  if (state == AutoRestoreState.none) return;

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
    await backup.restore();
    await ref.read(settingsProvider.notifier).reloadFromStore();
    ref.invalidate(localMediaProvider);
    ref.invalidate(playlistsProvider);
    if (context.mounted) {
      showMTSnack(context, l10n.autoRestoreSuccess,
          type: MTSnackType.success);
    }
  } on BackupKeyMismatchException {
    // الفخ الموروث: المفتاح ضاع مع إعادة التثبيت ⇒ الملف لا يُفك أبداً.
    if (context.mounted) await _offerOrphanReset(context, ref, backup);
  } catch (_) {
    if (context.mounted) {
      showMTSnack(context, l10n.restoreFailed, type: MTSnackType.error);
    }
  }
}

Future<void> _offerOrphanReset(
    BuildContext context, WidgetRef ref, AutoBackup backup) async {
  final l10n = context.mtl;
  final reset = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.backupOrphaned),
      content: Text(l10n.backupOrphanedMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.resetBackup),
        ),
      ],
    ),
  );
  if (reset != true) return;
  await backup.deleteFile();
  if (context.mounted) showMTSnack(context, l10n.backupReset);
}
