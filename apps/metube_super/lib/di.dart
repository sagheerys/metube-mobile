import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'features/batch/batch_offline_saver.dart';
import 'features/settings/auto_backup.dart';
import 'features/settings/settings_state.dart';
import 'features/shared/error_report.dart';
import 'features/shared/stores.dart';

/// Riverpod injection (TRD §3.1): a settings change rebuilds the client and
/// the engine automatically, with no Completers and no manual
/// synchronisation.

/// Overridden in main once SharedPreferences is ready.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('overridden in main'),
);

final secretStoreProvider = Provider<SecretStore>(
  (ref) => const SecureSecretStore(),
);

final prefsMutexProvider = Provider((ref) => PrefsMutex());

/// The initial snapshot loaded before runApp; overridden in main.
final initialSettingsProvider = Provider<SuperSettings>(
  (ref) => throw UnimplementedError('overridden in main'),
);

final settingsProvider = NotifierProvider<SettingsNotifier, SuperSettings>(
  SettingsNotifier.new,
);

/// The one Dio. It is rebuilt only when the server settings change.
final apiClientProvider = Provider<MeTubeApiClient?>((ref) {
  final config = ref.watch(settingsProvider.select((s) => s.serverConfig));
  if (config == null) return null;
  final client = MeTubeApiClient(config: config);
  ref.onDispose(client.close);
  return client;
});

final offlineIndexProvider = Provider(
  (ref) => OfflineIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

final tagsIndexProvider = Provider(
  (ref) => TagsIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
    // **A single choke point for the automatic backup** (2026-09-04):
    // every tag write, from any screen, requests a backup, so no screen
    // can be forgotten.
    onChanged: () => unawaited(ref.read(autoBackupProvider).requestBackup()),
  ),
);

final artworkIndexProvider = Provider(
  (ref) => ArtworkIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// **A single choke point for the automatic backup** (2026-09-04): every
/// playlist write, from any screen, requests a backup, so no screen can be
/// forgotten.
final probeFailureIndexProvider = Provider(
  (ref) => ProbeFailureIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

final playlistsStoreProvider = Provider(
  (ref) => PlaylistsStore(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
    // **A counter that invalidates the playlists cache** when they are
    // written from outside their own screen. Without it, an automatically
    // collected playlist stayed invisible until the app restarted
    // (confirmed
    // on the emulator 2026-09-03: the file on disk was correct and the
    // screen
    // was empty).
    onChanged: () => unawaited(ref.read(autoBackupProvider).requestBackup()),
  ),
);

/// Collects a playlist download into one saved playlist (asked 2026-09-02).
final batchCollectorProvider = Provider(
  (ref) => BatchPlaylistCollector(
    playlists: ref.watch(playlistsStoreProvider),
    onChanged: () => ref.read(playlistsRevisionProvider.notifier).state++,
  ),
);

/// Lite's engine: the whole four-stage pipeline. It pulls to the device and
/// then **deletes from the server automatically**, so the family's server
/// stays clean.
final playlistsRevisionProvider = StateProvider<int>((ref) => 0);

/// **Resolving short links before the routing decision** (field report
/// 2026-09-08): `on.soundcloud.com/…` is an album that contains no
/// `/sets/`, so it passed as a single clip and the server expanded it into
/// twenty. The engine resolves for itself later, and resolving what is
/// already resolved costs nothing (`needsResolution` returns false
/// immediately).
final shortLinkResolverProvider = Provider((ref) => ShortLinkResolver());

/// Super's engine: add to the server only (rule 2). No pull and no
/// automatic delete.
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
        throw StateError('Super does not pull from the add pipeline'),
    onCompleted: (task) {
      collector.onFinished(task);
      // When "save to device" was requested for this batch, applied to
      // every member.
      ref.read(batchOfflineSaverProvider).onFinished(task);
      ref.invalidate(historyProvider);
    },
    // Field report 2026-09-03: YouTube at "best" gives AV1 or VP9 and the
    // clip looks torn on phones. This asks for H.264/AAC instead.
    compatibleVideo: () => ref.read(settingsProvider).compatiblePlayback,
    // **The first log wiring in Super at all**: the logs screen used to
    // read a file nobody wrote to, so it was always empty (field report
    // 2026-09-02).
    onLog: (message) => unawaited(logger.log(message, tag: 'download')),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// A live snapshot of the engine's tasks, refreshed on every state update.
///
/// **The first `yield engine.tasks` is the fix for the ghost tasks:** a
/// StreamProvider keeps its previous value while rebuilding, and the new
/// engine broadcast nothing until the first `submit`, so the dead engine's
/// cards and its counter badge stayed on screen indefinitely after a server
/// switch.
final engineTasksProvider = StreamProvider<List<DownloadTask>>((ref) async* {
  final engine = ref.watch(downloadEngineProvider);
  if (engine == null) {
    yield const [];
    return;
  }
  yield engine.tasks;
  yield* engine.updates.map((_) => engine.tasks);
});

/// **Tells the collector which batch members dropped out** (failed or
/// cancelled), so the collected playlist does not hang waiting for them,
/// and is deleted if every one of its items drops.
final batchDropWatcherProvider = Provider<void>((ref) {
  final collector = ref.watch(batchCollectorProvider);
  ref.listen<AsyncValue<List<DownloadTask>>>(engineTasksProvider, (_, next) {
    for (final task in next.valueOrNull ?? const <DownloadTask>[]) {
      if (!task.isBatchMember) continue;
      if (task.phase == TaskPhase.failed || task.phase == TaskPhase.cancelled) {
        unawaited(collector.onDropped(task.id));
        ref.read(batchOfflineSaverProvider).forget(task.id);
      }
    }
  });
});

/// The unfinished tasks: the live library cards and the header badge.
final activeTasksProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(engineTasksProvider).valueOrNull ?? const [];
  return tasks.where((t) => !t.isFinished).toList();
});

/// Failed tasks: "needs your attention" in the management sheet.
final failedTasksProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(engineTasksProvider).valueOrNull ?? const [];
  return tasks.where((t) => t.phase == TaskPhase.failed).toList();
});

/// The server history. null before the server is configured; refreshed by
/// pull-to-refresh or by live polling.
final historyProvider = FutureProvider<HistoryResponse?>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  try {
    final history = await api.fetchHistory();
    clearErrorSignature('history');
    return history;
  } on MTApiException catch (e) {
    // **The source of every library failure**, and it was not being logged:
    // a crash on 2026-09-05 from a rejected credential passed without a
    // single line in the log. Once per signature, because live polling
    // every two seconds would repeat the same failure thirty times a
    // minute.
    unawaited(logErrorOnce(ref.read(loggerProvider), 'history', e));
    rethrow;
  }
});

/// Backups: writes the current format and reads the legacy ones.
final backupServiceProvider = Provider(
  (ref) => BackupService(
    store: ref.watch(keyValueStoreProvider),
    secrets: ref.watch(secretStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
    variant: 'super',
  ),
);

/// The diagnostic log; overridden in main with a path from path_provider.
final loggerProvider = Provider<MTLogger>(
  (ref) => throw UnimplementedError('overridden in main'),
);

// Playback.

final playbackPrefsProvider = Provider(
  (ref) => PlaybackPrefs(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

final playbackPositionsProvider = Provider(
  (ref) => PlaybackPositionStore(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// Clip dimensions, filled opportunistically on first play.
final mediaShapeIndexProvider = Provider(
  (ref) => MediaShapeIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

final audioStateStoreProvider = Provider(
  (ref) => AudioStateStore(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// Overridden in main. It is built before `AudioService.init` and shared
/// with video, so the golden rule applies with identical logic in both
/// players.
final playbackResolverProvider = Provider<PlaybackSourceResolver>(
  (ref) => throw UnimplementedError('overridden in main'),
);

/// The background audio handler; overridden in main after
/// `AudioService.init`.
final audioHandlerProvider = Provider<MTAudioHandler>(
  (ref) => throw UnimplementedError('overridden in main'),
);

/// Wires the current server URL into the source resolver, so a settings
/// change is picked up by the live player with no rebuild (the same pattern
/// as TRD §3.1).
final playbackWiringProvider = Provider<void>((ref) {
  final api = ref.watch(apiClientProvider);
  ref.watch(playbackResolverProvider).endpoint = api == null
      ? ServerStreamEndpoint.none
      : ServerStreamEndpoint.fromApi(api);
});

/// The endpoint resolver: it probes with the account's own credentials.
/// **It watches the credentials alone rather than the whole settings object
///:** without `select`, changing the theme or the quality rebuilt
/// the resolver, re-probing every endpoint while you were standing in the
/// network screen.
final endpointResolverProvider = Provider((ref) {
  final credentials = ref.watch(
    settingsProvider.select((s) => (s.username ?? '', s.password ?? '')),
  );
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
