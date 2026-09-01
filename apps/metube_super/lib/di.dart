import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

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
