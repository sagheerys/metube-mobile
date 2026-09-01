import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

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
    ));

final artworkIndexProvider = Provider((ref) => ArtworkIndex(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

final playlistsStoreProvider = Provider((ref) => PlaylistsStore(
      store: ref.watch(keyValueStoreProvider),
      mutex: ref.watch(prefsMutexProvider),
    ));

/// محرك Super: إضافة للسيرفر فقط (ر-2) — لا سحب ولا حذف تلقائي.
final downloadEngineProvider = Provider<DownloadEngine?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  final engine = DownloadEngine(
    api: api,
    policy: DeletePolicy.keepOnServer,
    pullToDevice: false,
    savePathBuilder: (task, filename) =>
        throw StateError('Super لا يسحب من خط الإضافة'),
    onCompleted: (task) => ref.invalidate(historyProvider),
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

/// المهام الفاشلة («تحتاج انتباهك» في ورقة الإدارة).
final failedTasksProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(engineTasksProvider).value ?? const [];
  return tasks.where((t) => t.phase == TaskPhase.failed).toList();
});

/// سجل السيرفر — null قبل تهيئة السيرفر؛ يُحدَّث بالسحب أو بالاستطلاع الحي.
final historyProvider = FutureProvider<HistoryResponse?>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  return api.fetchHistory();
});

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
final endpointResolverProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  return EndpointResolver.withClientFactory(
    (baseUrl) => MeTubeApiClient(
      config: ServerConfig(
        baseUrl: baseUrl,
        username: settings.username,
        password: settings.password,
      ),
    ),
  );
});
