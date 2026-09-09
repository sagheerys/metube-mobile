import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import '../settings/auto_backup.dart';
import 'library_providers.dart';
import 'media_store.dart';

final mediaStoreProvider = Provider((ref) => const MediaStoreScanner());

/// What happens after a download completes (rule 2, step 5): index the item
/// under its unified key, register it in the phone's gallery, refresh the
/// library, then take an automatic backup.
///
/// Deletion from the server happened inside the engine under
/// [DeletePolicy.autoDelete], using the canonicalUrl from `/history` (rule
/// 2). None of that is here.
Future<void> onDownloadCompleted(Ref ref, DownloadTask task) async {
  final path = task.localPath;
  if (path == null) return;
  final url = task.canonicalUrl;
  // The item key: the canonical URL when known, otherwise the path (the
  // same rule as the library).
  final key = (url != null && url.isNotEmpty) ? url : path;

  try {
    if (url != null && url.isNotEmpty) {
      await ref.read(offlineIndexProvider).put(url, path);
    }
    if (task.title != null && task.title!.isNotEmpty) {
      await ref.read(titleIndexProvider).put(key, task.title!);
    }
    // Image URLs are never invented (trap §6.3); only what the server gave.
    if (task.thumbnail != null && task.thumbnail!.isNotEmpty) {
      await ref.read(artworkIndexProvider).put(key, task.thumbnail!);
    }
    await ref.read(mediaStoreProvider).scanFile(path);
    await ref.read(loggerProvider).log('download completed', tag: 'download');
  } catch (e) {
    // A failed indexing does not cancel a file that exists on disk; the
    // library scans the folder.
    await ref
        .read(loggerProvider)
        .error('post-download indexing failed', cause: e, tag: 'download');
  }

  ref.invalidate(localMediaProvider);
  await ref.read(autoBackupProvider).requestBackup();
}
