import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:share_plus/share_plus.dart';

import '../../di.dart';
import '../settings/auto_backup.dart';
import 'download_wiring.dart';
import 'library_providers.dart';
import 'local_item.dart';

final libraryActionsProvider = Provider((ref) => LibraryActions(ref));

/// إجراءات عنصر المكتبة المحلية (ر-5 مبسطة لـ Lite): لا إجراءات سيرفر
/// — الملف على الهاتف هو كل شيء، والسيرفر نُظّف تلقائياً وقت التحميل.
class LibraryActions {
  LibraryActions(this._ref);

  final Ref _ref;

  /// م-36: المفضلة وسم نظامي بمفتاح العنصر — تدخل النسخة تلقائياً.
  Future<bool> toggleFavorite(String key) async {
    final tags = _ref.read(tagsIndexProvider);
    await tags.toggleTag(key, MTConstants.favoritesSystemTag);
    _ref.invalidate(localMediaProvider);
    await _ref.read(autoBackupProvider).requestBackup();
    return (await tags.tagsOf(key)).contains(MTConstants.favoritesSystemTag);
  }

  /// حذف الملفات نهائياً + تنظيف الفهارس + إعادة فحص المعرض حتى لا
  /// يبقى للملف المحذوف أثر في MediaStore (م-10).
  Future<int> deleteFiles(List<LocalItem> items) async {
    var deleted = 0;
    for (final item in items) {
      final file = File(item.path);
      if (await file.exists()) {
        await file.delete();
        deleted++;
      }
      final url = item.canonicalUrl;
      if (url != null) await _ref.read(offlineIndexProvider).removeKey(url);
      await _ref.read(titleIndexProvider).removeKey(item.key);
      await _ref.read(artworkIndexProvider).removeKey(item.key);
      await _ref.read(mediaStoreProvider).scanFile(item.path);
    }
    _ref.invalidate(localMediaProvider);
    await _ref.read(autoBackupProvider).requestBackup();
    return deleted;
  }

  /// مشاركة الملف نفسه — لا تحميل ولا سيرفر (كله محلي في Lite).
  Future<void> share(List<LocalItem> items) async {
    final files = [
      for (final item in items)
        if (File(item.path).existsSync()) XFile(item.path),
    ];
    if (files.isEmpty) return;
    await Share.shareXFiles(files);
  }
}
