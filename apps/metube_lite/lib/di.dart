import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'features/downloads_library/download_wiring.dart';
import 'features/downloads_library/local_item.dart';
import 'features/home/network_gate.dart';
import 'features/settings/auto_backup.dart';
import 'features/settings/settings_state.dart';
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
final initialSettingsProvider = Provider<LiteSettings>(
  (ref) => throw UnimplementedError('overridden in main'),
);

final settingsProvider = NotifierProvider<SettingsNotifier, LiteSettings>(
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

// The indexes (§5.5: all of them keyed by the unified item key).

/// canonicalUrl to the local path. In Lite it is filled after every
/// successful pull, so the URL stays associated with the file even after it
/// is deleted from the server, which it always is.
final offlineIndexProvider = Provider(
  (ref) => OfflineIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

final artworkIndexProvider = Provider(
  (ref) => ArtworkIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// Display titles, under the same key as the old Lite:
/// `video_title_metadata`.
final titleIndexProvider = Provider(
  (ref) => TitleIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// Lite has no user tags (that is a Super feature); this is used for the
/// system "favourites" tag alone.
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

/// Lite's engine: the whole four-stage pipeline. It pulls to the device and
/// then **deletes from the server automatically**, so the family's server
/// stays clean.
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
    // Field report 2026-09-03: YouTube at "best" gives AV1 or VP9 and the
    // clip looks torn on phones. This asks for H.264/AAC instead.
    pullGate: () {
      if (!ref.read(settingsProvider).wifiOnly) return true;
      return ref.read(networkGateProvider).onWifi;
    },
    // Field report 2026-09-03: YouTube at "best" gives AV1 or VP9 and the
    // clip looks torn on phones. This asks for H.264/AAC instead.
    compatibleVideo: () => ref.read(settingsProvider).compatiblePlayback,
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// A live snapshot of the engine's tasks, refreshed on every state update.
///
/// **The first `yield engine.tasks` is the fix for the ع-1 ghosts:** a
/// StreamProvider keeps its previous value while rebuilding, and the new
/// engine does not broadcast until the first `submit`, so the dead engine's
/// tasks stayed on display — and in Lite **the foreground service never
/// switched off**, because it follows the live task count.
final engineTasksProvider = StreamProvider<List<DownloadTask>>((ref) async* {
  final engine = ref.watch(downloadEngineProvider);
  if (engine == null) {
    yield const [];
    return;
  }
  yield engine.tasks;
  yield* engine.updates.map((_) => engine.tasks);
});

/// The server history. null before the server is configured; refreshed by
/// pull-to-refresh or by live polling.
final batchDropWatcherProvider = Provider<void>((ref) {
  final collector = ref.watch(batchCollectorProvider);
  ref.listen<AsyncValue<List<DownloadTask>>>(engineTasksProvider, (_, next) {
    for (final task in next.valueOrNull ?? const <DownloadTask>[]) {
      if (!task.isBatchMember) continue;
      if (task.phase == TaskPhase.failed || task.phase == TaskPhase.cancelled) {
        unawaited(collector.onDropped(task.id));
      }
    }
  });
});

/// The server history. null before the server is configured; refreshed by
/// pull-to-refresh or by live polling.
final activeTasksProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(engineTasksProvider).valueOrNull ?? const [];
  return tasks.where((t) => !t.isFinished).toList();
});

/// Clip dimensions, filled opportunistically on first play.
final backupServiceProvider = Provider(
  (ref) => BackupService(
    store: ref.watch(keyValueStoreProvider),
    secrets: ref.watch(secretStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
    variant: 'lite',
  ),
);

/// Clip dimensions, filled opportunistically on first play.
final loggerProvider = Provider<MTLogger>(
  (ref) => throw UnimplementedError('overridden in main'),
);

// Playback (mt_media is reused in full).

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

/// Overridden in main. **Lite never streams**: its library is entirely
/// local, so the endpoint stays `none` and the golden rule always ends at
/// the local file.
final playbackResolverProvider = Provider<PlaybackSourceResolver>(
  (ref) => throw UnimplementedError('overridden in main'),
);

/// The background audio handler; overridden in main after
/// `AudioService.init`.
final audioHandlerProvider = Provider<MTAudioHandler>(
  (ref) => throw UnimplementedError('overridden in main'),
);
