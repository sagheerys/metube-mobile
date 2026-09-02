import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../di.dart';
import '../home/network_gate.dart';
import 'library_models.dart';
import 'library_providers.dart';

/// مجلد وسائط Super «دون اتصال» (§5.3).
const superMediaDir = '/storage/emulated/0/Download/MeTube_Super';

/// وسم `detail` الذي يميّز رفضَ «Wi‑Fi فقط» عن انقطاع شبكة حقيقي (م-42)
/// — يقرؤه `errorText` ليعرض الرسالة الصحيحة.
const wifiOnlyRejection = 'wifi-only';

/// تقدم سحب «إتاحة دون اتصال» الجاري: canonicalUrl → 0..1.
final offlinePullProgressProvider =
    StateProvider<Map<String, double>>((ref) => {});

final libraryActionsProvider = Provider((ref) => LibraryActions(ref));

/// إجراءات عنصر المكتبة (ر-5 / م-17) — كل شبكة عبر عميل النواة حصراً.
class LibraryActions {
  LibraryActions(this._ref);

  final Ref _ref;

  MeTubeApiClient get _api {
    final api = _ref.read(apiClientProvider);
    if (api == null) throw const NetworkException('no server configured');
    return api;
  }

  void _refreshLibrary() {
    _ref.invalidate(historyProvider);
    _ref.invalidate(libraryItemsProvider);
  }

  /// م-36: المفضلة وسم نظامي — تدخل النسخ الاحتياطي تلقائياً.
  Future<bool> toggleFavorite(String canonicalUrl) async {
    final tags = _ref.read(tagsIndexProvider);
    await tags.toggleTag(canonicalUrl, MTConstants.favoritesSystemTag);
    _ref.invalidate(libraryItemsProvider);
    return (await tags.tagsOf(canonicalUrl))
        .contains(MTConstants.favoritesSystemTag);
  }

  /// م-42: هل يُسمح بسحب ملف للجهاز الآن؟ (يُسأل قبل «إتاحة دون اتصال»
  /// وقبل المشاركة التي تسحب نسخة مؤقتة.)
  bool get canPullNow =>
      !_ref.read(settingsProvider).wifiOnly ||
      _ref.read(networkGateProvider).onWifi;

  /// «إتاحة دون اتصال» (م-17): سحب بتقدم مع بقاء الأصل على السيرفر.
  Future<String> makeOffline(LibraryItem item) async {
    // **يُرفض صراحةً لا ينتظر**: خط الإضافة في Lite له طابور يصبر فيه
    // العنصر، أما هذا فعل مباشر بنقرة المستخدم — تركه صامتاً «يفكر»
    // بلا نهاية أسوأ من إخباره أن Wi‑Fi هو الشرط.
    if (!canPullNow) throw const NetworkException(wifiOnlyRejection);
    final filename = item.serverFilename;
    if (filename == null) throw const UnsafeFilenameException();
    final dir = Directory(superMediaDir);
    await dir.create(recursive: true);
    final savePath =
        '$superMediaDir/${buildLocalFilename(item.title, serverFilename: filename)}';

    _setProgress(item.canonicalUrl, 0);
    final String finalPath;
    try {
      // المسار النهائي من `pull` — التصادم يزيحه (خ-3)، وفهرسة المسار
      // المطلوب بدله كانت ستشير إلى ملف غيره.
      finalPath = await Transfer(api: _api).pull(
        serverFilename: filename,
        savePath: savePath,
        onProgress: (p) => _setProgress(item.canonicalUrl, p),
      );
    } finally {
      _clearProgress(item.canonicalUrl);
    }
    await _ref.read(offlineIndexProvider).put(item.canonicalUrl, finalPath);
    if (item.thumbnail != null) {
      await _ref
          .read(artworkIndexProvider)
          .put(item.canonicalUrl, item.thumbnail!);
    }
    _refreshLibrary();
    return finalPath;
  }

  /// حذف من السيرفر — **بالـ canonicalUrl من /history حصراً** (القاعدة 2).
  Future<void> deleteFromServer(List<String> canonicalUrls) async {
    await _api.delete(canonicalUrls);
    await pruneItemData(canonicalUrls);
    _refreshLibrary();
  }

  /// **تشذيب بيانات عنصر مُزال (إصلاح خ-4).** الحذف كان يشذّب فهرس
  /// دون-الاتصال وحده، بينما تبقى الوسوم والمواضع والأبعاد والعنوان
  /// والغلاف **للأبد** في نفس ملف XML الذي يُعاد تسلسله مع كل كتابة —
  /// وينسخه `exportToString` كاملاً، فتتضخم النسخ الاحتياطية بجثث.
  Future<void> pruneItemData(List<String> canonicalUrls) async {
    final tags = _ref.read(tagsIndexProvider);
    final artwork = _ref.read(artworkIndexProvider);
    final shapes = _ref.read(mediaShapeIndexProvider);
    final positions = _ref.read(playbackPositionsProvider);
    final offline = _ref.read(offlineIndexProvider);
    for (final url in canonicalUrls) {
      await tags.removeKey(url);
      await artwork.removeKey(url);
      await shapes.removeKey(url);
      await positions.clear(url);
      await offline.removeKey(url);
    }
  }

  /// إزالة النسخة المحلية فقط (يبقى على السيرفر).
  Future<void> removeLocalCopy(LibraryItem item) async {
    final path = item.localPath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _ref.read(offlineIndexProvider).removeKey(item.canonicalUrl);
    _refreshLibrary();
  }

  /// حذف عنصر محلي-فقط نهائياً.
  Future<void> deleteLocalOnly(LibraryItem item) => removeLocalCopy(item);

  /// مشاركة ذكية (م-17): الملف المحلي إن وُجد وإلا تحميل-ثم-مشاركة.
  /// **بلاغ المالك 2026-09-02:** «لا يظهر عداد أنه يحمّل، يبدو كأنه لا
  /// يستجيب». التقدّم كان يُحسب في [offlinePullProgressProvider] ولا
  /// يعرضه أحد — الآن تعرضه شاشات المشاركة، والملف المؤقت **يُحذف بعد
  /// المشاركة** بدل تركه يتراكم في مجلد النظام المؤقت.
  Future<void> smartShare(LibraryItem item) async {
    final localPath = item.localPath;
    if (localPath != null) {
      await Share.shareXFiles([XFile(localPath)]);
      return;
    }
    if (!canPullNow) throw const NetworkException(wifiOnlyRejection);
    final filename = item.serverFilename;
    if (filename == null) throw const UnsafeFilenameException();
    final tmp = await getTemporaryDirectory();
    final path =
        '${tmp.path}/${buildLocalFilename(item.title, serverFilename: filename)}';
    _setProgress(item.canonicalUrl, 0);
    try {
      await Transfer(api: _api).pull(
        serverFilename: filename,
        savePath: path,
        onProgress: (p) => _setProgress(item.canonicalUrl, p),
      );
    } finally {
      _clearProgress(item.canonicalUrl);
    }
    try {
      await Share.shareXFiles([XFile(path)]);
    } finally {
      // نسخة عابرة لا يعرفها فهرس «دون اتصال» — تركها تسريب صامت.
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // تطبيق المشاركة ما زال يقرؤه — ينظفه النظام لاحقاً.
      }
    }
  }

  void _setProgress(String url, double value) {
    final map =
        Map<String, double>.from(_ref.read(offlinePullProgressProvider));
    map[url] = value;
    _ref.read(offlinePullProgressProvider.notifier).state = map;
  }

  void _clearProgress(String url) {
    final map =
        Map<String, double>.from(_ref.read(offlinePullProgressProvider));
    map.remove(url);
    _ref.read(offlinePullProgressProvider.notifier).state = map;
  }
}
