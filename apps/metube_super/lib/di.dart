import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'features/batch/batch_offline_saver.dart';
import 'features/settings/auto_backup.dart';
import 'features/settings/settings_state.dart';
import 'features/shared/error_report.dart';
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
final initialSettingsProvider = Provider<SuperSettings>(
    (ref) => throw UnimplementedError('overridden in main'));

final settingsProvider =
    NotifierProvider<SettingsNotifier, SuperSettings>(SettingsNotifier.new);

/// الـ Dio الوحيد — يعاد بناؤه عند تغيّر إعدادات السيرفر فقط.
final apiClientProvider = Provider<MeTubeApiClient?>((ref) {
  final config =
      ref.watch(settingsProvider.select((s) => s.serverConfig));
  if (config == null) return null;
  final client = MeTubeApiClient(config: config);
  ref.onDispose(client.close);
  return client;
});

final offlineIndexProvider = Provider((ref) => OfflineIndex(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

final tagsIndexProvider = Provider((ref) => TagsIndex(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
      // **نقطة اختناق واحدة للنسخة التلقائية** (2026-09-04): كل كتابة
      // وسم — من أي شاشة — تطلب نسخة، فلا تُنسى شاشة.
      onChanged: () =>
          unawaited(ref.read(autoBackupProvider).requestBackup()),
    ));

final artworkIndexProvider = Provider((ref) => ArtworkIndex(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

final playlistsStoreProvider = Provider((ref) => PlaylistsStore(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
      // **نقطة اختناق واحدة للنسخة التلقائية** (2026-09-04): كل كتابة
      // قوائم — من أي شاشة — تطلب نسخة، فلا تُنسى شاشة.
      onChanged: () =>
          unawaited(ref.read(autoBackupProvider).requestBackup()),
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

/// محرك Super: إضافة للسيرفر فقط (ر-2) — لا سحب ولا حذف تلقائي.
final downloadEngineProvider = Provider<DownloadEngine?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  final logger = ref.watch(loggerProvider);
  final collector = ref.watch(batchCollectorProvider);
  final engine = DownloadEngine(
    api: api,
    policy: DeletePolicy.keepOnServer,
    pullToDevice: false,
    savePathBuilder: (task, filename) =>
        throw StateError('Super لا يسحب من خط الإضافة'),
    onCompleted: (task) {
      collector.onFinished(task);
      // إن طلب المالك «احفظ على الجهاز» لهذه الدفعة (م-17 على كل عضو).
      ref.read(batchOfflineSaverProvider).onFinished(task);
      ref.invalidate(historyProvider);
    },
    // بلاغ المالك 2026-09-03: يوتيوب «الأفضل» يعطي AV1/VP9 فيظهر المقطع
    // مشوشاً على الهواتف — هذا يطلب H.264/AAC بدلها.
    compatibleVideo: () => ref.read(settingsProvider).compatiblePlayback,
    // م-32: **أول موصل سجل في Super إطلاقاً** — كانت شاشة السجلات تقرأ
    // ملفاً لا يكتب فيه أحد، فتظهر فارغة دائماً (بلاغ المالك 2026-09-02).
    onLog: (message) => unawaited(logger.log(message, tag: 'download')),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// لقطة مهام المحرك الحية — تتجدد مع كل تحديث حالة.
///
/// **`yield engine.tasks` الأولى هي إصلاح أشباح ع-1:** StreamProvider
/// يحتفظ بقيمته السابقة أثناء إعادة البناء، والمحرك الجديد لم يكن يبثّ
/// شيئاً حتى أول `submit` — فتبقى بطاقات المحرك الميت وشارة عدّاده
/// معروضة إلى ما لا نهاية بعد تبديل السيرفر.
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
    for (final task in next.valueOrNull ?? const <DownloadTask>[]) {
      if (!task.isBatchMember) continue;
      if (task.phase == TaskPhase.failed ||
          task.phase == TaskPhase.cancelled) {
        unawaited(collector.onDropped(task.id));
        ref.read(batchOfflineSaverProvider).forget(task.id);
      }
    }
  });
});

/// المهام غير المنتهية (بطاقات المكتبة الحية + شارة الرأس — النموذج أ).
final activeTasksProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(engineTasksProvider).valueOrNull ?? const [];
  return tasks.where((t) => !t.isFinished).toList();
});

/// المهام الفاشلة («تحتاج انتباهك» في ورقة الإدارة).
final failedTasksProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(engineTasksProvider).valueOrNull ?? const [];
  return tasks.where((t) => t.phase == TaskPhase.failed).toList();
});

/// سجل السيرفر — null قبل تهيئة السيرفر؛ يُحدَّث بالسحب أو بالاستطلاع الحي.
final historyProvider = FutureProvider<HistoryResponse?>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  try {
    final history = await api.fetchHistory();
    clearErrorSignature('history');
    return history;
  } on MTApiException catch (e) {
    // **مصدر كل أعطال المكتبة** وكان لا يُسجَّل: انهيار 2026-09-05
    // (رفض الاعتماد) مرّ بلا سطر واحد في السجل. ومرة لكل توقيع لأن
    // الاستطلاع الحي كل ثانيتين يعيد العطل ثلاثين مرة في الدقيقة.
    unawaited(logErrorOnce(ref.read(loggerProvider), 'history', e));
    rethrow;
  }
});

/// النسخ الاحتياطي (م-31) — يكتب v2 ويقرأ التنسيقات الثلاثة.
final backupServiceProvider = Provider((ref) => BackupService(
      store: ref.watch(keyValueStoreProvider),
      secrets: ref.watch(secretStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
      variant: 'super',
    ));

/// السجل التشخيصي (م-32) — يُتجاوز في main بمسار من path_provider.
final loggerProvider = Provider<MTLogger>(
    (ref) => throw UnimplementedError('overridden in main'));

// ── التشغيل (المرحلة 5) ──

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

/// يُتجاوز في main — يُبنى قبل `AudioService.init` ويُشارَك مع الفيديو
/// فتنطبق القاعدة الذهبية بنفس المنطق على المشغلين.
final playbackResolverProvider = Provider<PlaybackSourceResolver>(
    (ref) => throw UnimplementedError('overridden in main'));

/// معالج الصوت الخلفي — يُتجاوز في main بعد `AudioService.init`.
final audioHandlerProvider = Provider<MTAudioHandler>(
    (ref) => throw UnimplementedError('overridden in main'));

/// يوصل رابط السيرفر الحالي بمحلّل المصادر — تغيّر الإعدادات يلتقطه
/// المشغل الحي بلا إعادة بناء (نفس نمط TRD §3.1).
final playbackWiringProvider = Provider<void>((ref) {
  final api = ref.watch(apiClientProvider);
  ref.watch(playbackResolverProvider).endpoint = api == null
      ? ServerStreamEndpoint.none
      : ServerStreamEndpoint.fromApi(api);
});

/// محلّل الروابط (م-28): probe بنفس اعتمادات الحساب.
/// **يراقب الاعتمادات وحدها لا كائن الإعدادات كله (إصلاح ط-6):** بلا
/// `select` كان تغيير الثيم أو الجودة يعيد بناء المحلّل، فيُعاد فحص كل
/// الروابط وأنت في شاشة الشبكة.
final endpointResolverProvider = Provider((ref) {
  final credentials = ref.watch(
      settingsProvider.select((s) => (s.username ?? '', s.password ?? '')));
  return EndpointResolver.withClientFactory(
    (baseUrl) => MeTubeApiClient(
      config: ServerConfig(
        baseUrl: baseUrl,
        username: credentials.$1,
        password: credentials.$2,
      ),
    ),
  );
});
