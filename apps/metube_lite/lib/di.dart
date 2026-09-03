import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'features/downloads_library/download_wiring.dart';
import 'features/downloads_library/local_item.dart';
import 'features/home/network_gate.dart';
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

/// تجميع تحميل القائمة في قائمة محفوظة واحدة (بلاغ المالك 2026-09-02).
final batchCollectorProvider = Provider((ref) => BatchPlaylistCollector(
      playlists: ref.watch(playlistsStoreProvider),
      onChanged: () =>
          ref.read(playlistsRevisionProvider.notifier).state++,
    ));

/// **عدّاد يُبطل تخبئة القوائم** حين تُكتب من خارج شاشتها. بلا هذا كانت
/// القائمة المُجمَّعة تلقائياً تبقى غير مرئية حتى إعادة تشغيل التطبيق
/// (مثبت على المحاكي 2026-09-03: الملف على القرص صحيح والشاشة فارغة).
final playlistsRevisionProvider = StateProvider<int>((ref) => 0);

/// محرك Lite: الخط الرباعي كاملاً — يسحب للجهاز ثم **يحذف من السيرفر
/// تلقائياً** (م-6/4) فيبقى سيرفر العائلة نظيفاً.
final downloadEngineProvider = Provider<DownloadEngine?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  final logger = ref.watch(loggerProvider);
  final collector = ref.watch(batchCollectorProvider);
  final engine = DownloadEngine(
    api: api,
    policy: DeletePolicy.autoDelete,
    savePathBuilder: (task, filename) =>
        '$liteMediaDir/${buildLocalFilename(task.title, serverFilename: filename)}',
    onCompleted: (task) {
      unawaited(collector.onFinished(task));
      unawaited(onDownloadCompleted(ref, task));
    },
    onLog: (message) => unawaited(logger.log(message, tag: 'download')),
    // م-42: الملف لا يُسحب على بيانات الجوّال إن اختار المستخدم ذلك.
    // `ref.read` داخل الإغلاق بقصد: قراءة **لحظة السؤال**، فتغيير
    // الإعداد أثناء انتظار مهمة يُطلقها فوراً بلا إعادة بناء المحرك.
    pullGate: () {
      if (!ref.read(settingsProvider).wifiOnly) return true;
      return ref.read(networkGateProvider).onWifi;
    },
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// لقطة مهام المحرك الحية — تتجدد مع كل تحديث حالة.
///
/// **`yield engine.tasks` الأولى هي إصلاح أشباح ع-1:** StreamProvider
/// يحتفظ بقيمته السابقة أثناء إعادة البناء، والمحرك الجديد لا يبثّ حتى
/// أول `submit` — فتبقى مهام المحرك الميت معروضة، وفي Lite **لا تنطفئ
/// الخدمة الأمامية** لأنها تتبع عدّاد المهام الحية.
final engineTasksProvider = StreamProvider<List<DownloadTask>>((ref) async* {
  final engine = ref.watch(downloadEngineProvider);
  if (engine == null) {
    yield const [];
    return;
  }
  yield engine.tasks;
  yield* engine.updates.map((_) => engine.tasks);
});

/// **يبلّغ المُجمِّع بأعضاء الدفعة التي سقطت** (فشل/إلغاء) كي لا تبقى
/// قائمة القائمة المُجمَّعة معلّقة، وتُحذف إن سقط كل عناصرها.
final batchDropWatcherProvider = Provider<void>((ref) {
  final collector = ref.watch(batchCollectorProvider);
  ref.listen<AsyncValue<List<DownloadTask>>>(engineTasksProvider, (_, next) {
    for (final task in next.value ?? const <DownloadTask>[]) {
      if (!task.isBatchMember) continue;
      if (task.phase == TaskPhase.failed ||
          task.phase == TaskPhase.cancelled) {
        unawaited(collector.onDropped(task.id));
      }
    }
  });
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
