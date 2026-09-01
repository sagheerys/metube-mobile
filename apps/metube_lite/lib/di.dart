import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'features/downloads_library/download_wiring.dart';
import 'features/downloads_library/local_item.dart';
import 'features/settings/settings_state.dart';
import 'features/shared/stores.dart';

/// حقن Riverpod (TRD §3.1): تغيّر الإعدادات يعيد بناء العميل والمحرك
/// تلقائياً — لا Completers ولا تزامن يدوي.

/// يُتجاوز في main بعد تهيئة SharedPreferences.
final keyValueStoreProvider = Provider<KeyValueStore>(
    (ref) => throw UnimplementedError('overridden in main'));

final secretStoreProvider =
    Provider<SecretStore>((ref) => const SecureSecretStore());

final prefsMutexProvider = Provider((ref) => PrefsMutex());

/// اللقطة الأولية المحملة قبل runApp — تُتجاوز في main.
final initialSettingsProvider = Provider<LiteSettings>(
    (ref) => throw UnimplementedError('overridden in main'));

final settingsProvider =
    NotifierProvider<SettingsNotifier, LiteSettings>(SettingsNotifier.new);

/// الـ Dio الوحيد — يعاد بناؤه عند تغيّر إعدادات السيرفر فقط.
final apiClientProvider = Provider<MeTubeApiClient?>((ref) {
  final config = ref.watch(settingsProvider.select((s) => s.serverConfig));
  if (config == null) return null;
  final client = MeTubeApiClient(config: config);
  ref.onDispose(client.close);
  return client;
});

// ── الفهارس (§5.5: كلها بمفتاح العنصر الموحد) ──

/// canonicalUrl → المسار المحلي: في Lite يُملأ بعد كل سحب ناجح، فيبقى
/// الرابط معروفاً للملف حتى بعد حذفه من السيرفر (وهو الحال دائماً).
final offlineIndexProvider = Provider((ref) => OfflineIndex(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

final artworkIndexProvider = Provider((ref) => ArtworkIndex(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

/// عناوين العرض — نفس مفتاح Lite القديم `video_title_metadata`.
final titleIndexProvider = Provider((ref) => TitleIndex(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

/// Lite بلا وسوم مستخدم (م-26 ميزة Super) — يُستعمل للوسم النظامي
/// «المفضلة» وحده (م-36).
final tagsIndexProvider = Provider((ref) => TagsIndex(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

final playlistsStoreProvider = Provider((ref) => PlaylistsStore(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

/// محرك Lite: الخط الرباعي كاملاً — يسحب للجهاز ثم **يحذف من السيرفر
/// تلقائياً** (م-6/4) فيبقى سيرفر العائلة نظيفاً.
final downloadEngineProvider = Provider<DownloadEngine?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  final engine = DownloadEngine(
    api: api,
    policy: DeletePolicy.autoDelete,
    savePathBuilder: (task, filename) =>
        '$liteMediaDir/${buildLocalFilename(task.title, serverFilename: filename)}',
    onCompleted: (task) => unawaited(onDownloadCompleted(ref, task)),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// لقطة مهام المحرك الحية — تتجدد مع كل تحديث حالة.
final engineTasksProvider = StreamProvider<List<DownloadTask>>((ref) {
  final engine = ref.watch(downloadEngineProvider);
  if (engine == null) return const Stream.empty();
  return engine.updates.map((_) => engine.tasks);
});

/// المهام غير المنتهية (بطاقات المكتبة الحية + شارة الرأس — النموذج أ).
final activeTasksProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(engineTasksProvider).value ?? const [];
  return tasks.where((t) => !t.isFinished).toList();
});

/// النسخ الاحتياطي (م-31) — يكتب v2 ويقرأ التنسيقات الثلاثة.
final backupServiceProvider = Provider((ref) => BackupService(
      store: ref.watch(keyValueStoreProvider),
      secrets: ref.watch(secretStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
      variant: 'lite',
    ));

/// السجل التشخيصي (م-32) — يُتجاوز في main بمسار من path_provider.
final loggerProvider = Provider<MTLogger>(
    (ref) => throw UnimplementedError('overridden in main'));

// ── التشغيل (mt_media يُعاد استخدامه كاملاً) ──

final playbackPrefsProvider = Provider((ref) => PlaybackPrefs(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

final playbackPositionsProvider = Provider((ref) => PlaybackPositionStore(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

/// أبعاد المقاطع (م-35) — تُملأ انتهازياً عند أول تشغيل.
final mediaShapeIndexProvider = Provider((ref) => MediaShapeIndex(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

final audioStateStoreProvider = Provider((ref) => AudioStateStore(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

/// يُتجاوز في main. **Lite لا يبث إطلاقاً**: مكتبته محلية بالكامل،
/// فيبقى المنفذ `none` والقاعدة الذهبية تنتهي دائماً إلى الملف المحلي.
final playbackResolverProvider = Provider<PlaybackSourceResolver>(
    (ref) => throw UnimplementedError('overridden in main'));

/// معالج الصوت الخلفي — يُتجاوز في main بعد `AudioService.init`.
final audioHandlerProvider = Provider<MTAudioHandler>(
    (ref) => throw UnimplementedError('overridden in main'));
