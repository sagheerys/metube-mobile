import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';

import '../di.dart';
import 'addresses_data.dart';
import 'library_watch.dart';
import 'setup_data.dart';

/// The server to talk to: the set-up account at the address chosen in
/// Settings › Addresses; null until one is set up.
final serverConfigProvider = Provider<ServerConfig?>((ref) {
  final setup = ref.watch(serverSetupProvider);
  if (setup == null) return null;
  return setup.at(
    ref.watch(addressesProvider.select((a) => a.active)) ?? setup.baseUrl,
  );
});

/// The one HTTP client, rebuilt only when the server changes.
final apiClientProvider = Provider<MeTubeApiClient?>((ref) {
  final config = ref.watch(serverConfigProvider);
  if (config == null) return null;
  final client = MeTubeApiClient(config: config);
  ref.onDispose(client.close);
  return client;
});

/// The server history, without the transcripts' own entries (they are not
/// clips). Null with no server.
final historyProvider = FutureProvider<HistoryResponse?>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  // The watcher's fresh list, when it is what brought this here.
  if (ref.read(historyHandoffProvider).take() case final fresh?) return fresh;
  return (await api.fetchHistory()).withoutCaptions();
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
    // Stamped like Super's, so a later merge with the phone knows which
    // write is newer.
    clock: DateTime.now,
  ),
);

final artworkIndexProvider = Provider(
  (ref) => ArtworkIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// Online covers kept as files on this computer (see CoverKeeper).
final keptCoverIndexProvider = Provider(
  (ref) => KeptCoverIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

final mediaShapeIndexProvider = Provider(
  (ref) => MediaShapeIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// The unified library, merged exactly as on the phone.
///
/// **Local copies are read first and an unreachable server does not hide
/// them**: the last good history stands in, and [libraryServerErrorProvider]
/// says why the server part is missing. Only a rejected credential, or
/// nothing at all to show, is an error for the whole page.
final libraryItemsProvider = FutureProvider<List<LibraryItem>>((ref) async {
  final offline = await ref.watch(offlineIndexProvider).readAll();
  HistoryResponse? history;
  try {
    history = await ref.watch(historyProvider.future);
  } on AuthFailureException {
    rethrow;
  } on MTApiException {
    final lastGood = ref.read(historyProvider).valueOrNull;
    if (lastGood == null && offline.isEmpty) rethrow;
    history = lastGood;
  }
  return mergeLibrary(
    history: history,
    offline: offline,
    tags: await ref.watch(tagsIndexProvider).readAll(),
    artwork: await ref.watch(artworkIndexProvider).readAll(),
    shapes: await ref.watch(mediaShapeIndexProvider).readAll(),
    kept: await ref.watch(keptCoverIndexProvider).readAll(),
  );
});

/// Why the server part of the library is missing; null when it answers.
final libraryServerErrorProvider = Provider<Object?>((ref) {
  final history = ref.watch(historyProvider);
  return history.hasError ? history.error : null;
});

/// The last session, back paused, as on the phone: opening the app never
/// starts sound by itself. Watched by the shell once.
///
/// **Only after the player knows the server** ([playbackWiringProvider]):
/// restored before it, every clip not on this computer had no address, was
/// skipped as broken, and the whole queue emptied itself at start-up
/// (measured on the real window).
final sessionRestoreProvider = FutureProvider<bool>((ref) {
  ref.read(playbackWiringProvider);
  return ref.read(playerProvider).restoreSession();
});

/// Points the player at the current server, so a clip that is not on this
/// computer streams from it, with its credentials.
final playbackWiringProvider = Provider<void>((ref) {
  final api = ref.watch(apiClientProvider);
  ref.watch(playbackResolverProvider).endpoint = api == null
      ? ServerStreamEndpoint.none
      : ServerStreamEndpoint.fromApi(api);
});
