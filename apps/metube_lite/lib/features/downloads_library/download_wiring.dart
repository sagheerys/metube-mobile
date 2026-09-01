import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import '../settings/auto_backup.dart';
import 'library_providers.dart';
import 'media_store.dart';

final mediaStoreProvider = Provider((ref) => const MediaStoreScanner());

/// ما بعد اكتمال التحميل (ر-2 خطوة 5): فهرسة العنصر بمفتاحه الموحد،
/// تسجيله في معرض الهاتف (م-10)، تحديث المكتبة، ثم نسخة تلقائية (م-31).
///
/// الحذف من السيرفر تم داخل المحرك بسياسة [DeletePolicy.autoDelete]
/// بالـ canonicalUrl من `/history` (القاعدة 2) — لا شيء منه هنا.
Future<void> onDownloadCompleted(Ref ref, DownloadTask task) async {
  final path = task.localPath;
  if (path == null) return;
  final url = task.canonicalUrl;
  // مفتاح العنصر: الرابط المُقنون إن عُرف وإلا المسار (نفس قاعدة المكتبة).
  final key = (url != null && url.isNotEmpty) ? url : path;

  try {
    if (url != null && url.isNotEmpty) {
      await ref.read(offlineIndexProvider).put(url, path);
    }
    if (task.title != null && task.title!.isNotEmpty) {
      await ref.read(titleIndexProvider).put(key, task.title!);
    }
    // لا تُختلق روابط صور (فخ §6.3) — فقط ما أعطاه السيرفر.
    if (task.thumbnail != null && task.thumbnail!.isNotEmpty) {
      await ref.read(artworkIndexProvider).put(key, task.thumbnail!);
    }
    await ref.read(mediaStoreProvider).scanFile(path);
    await ref.read(loggerProvider).log('download completed', tag: 'download');
  } catch (e) {
    // فهرسة فاشلة لا تُلغي ملفاً موجوداً على القرص — المكتبة تمسح المجلد.
    await ref
        .read(loggerProvider)
        .error('post-download indexing failed', cause: e, tag: 'download');
  }

  ref.invalidate(localMediaProvider);
  await ref.read(autoBackupProvider).requestBackup();
}
