import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart' show mtLocalizationsFor;
import 'package:path_provider/path_provider.dart';

import '../../di.dart';

/// "Search inside clips": off until the user turns it on.
final transcriptsEnabledProvider =
    AsyncNotifierProvider<TranscriptsEnabled, bool>(TranscriptsEnabled.new);

class TranscriptsEnabled extends AsyncNotifier<bool> {
  static const prefsKey = 'transcripts_enabled';

  @override
  Future<bool> build() async =>
      await ref.watch(keyValueStoreProvider).getBool(prefsKey) ?? false;

  Future<void> set(bool enabled) async {
    final store = ref.read(keyValueStoreProvider);
    await ref
        .read(prefsMutexProvider)
        .run(() => store.setBool(prefsKey, enabled));
    state = AsyncData(enabled);
  }
}

/// The folder the transcripts live in: the app's own files, which Android
/// never clears the way it clears a cache. Excluded from Google's cloud
/// backup in `backup_rules.xml`, whose 25MB ceiling a large library would
/// otherwise break for every other setting too.
final transcriptsRootProvider = FutureProvider<Directory>(
  (ref) async => Directory(
    '${(await getApplicationSupportDirectory()).path}'
    '${Platform.pathSeparator}transcripts',
  ),
);

final transcriptStoreProvider = FutureProvider<TranscriptStore>(
  (ref) async =>
      TranscriptStore(await ref.watch(transcriptsRootProvider.future)),
);

/// The search index, built from the files at launch. Empty while the
/// feature is off, so a phone that never turns it on never reads the folder.
final transcriptIndexProvider = FutureProvider<TranscriptIndex>((ref) async {
  final index = TranscriptIndex();
  if (!await ref.watch(transcriptsEnabledProvider.future)) return index;
  final store = await ref.watch(transcriptStoreProvider.future);
  await for (final transcript in store.readAll()) {
    index.add(transcript);
  }
  return index;
});

/// Bumped whenever a transcript is added or removed, so a search on screen
/// shows the new state without rebuilding the whole index.
final transcriptsRevisionProvider = StateProvider<int>((ref) => 0);

/// How many clips have a transcript, and the space they take.
final transcriptStatsProvider = FutureProvider<({int clips, int bytes})>((
  ref,
) async {
  ref.watch(transcriptsRevisionProvider);
  final index = await ref.watch(transcriptIndexProvider.future);
  final store = await ref.watch(transcriptStoreProvider.future);
  return (clips: index.length, bytes: await store.sizeBytes());
});

/// How a fetcher is made for the engine's API; a test swaps in one that
/// does not wait between readings.
final captionsFetcherFactoryProvider =
    Provider<CaptionsFetcher Function(MeTubeApi)>((ref) => CaptionsFetcher.new);

final transcriptsServiceProvider = Provider((ref) => TranscriptsService(ref));

class TranscriptsService {
  TranscriptsService(this._ref);

  final Ref _ref;

  /// The download engine's hook, run before each clip is added.
  ///
  /// Batch members are skipped: a playlist of fifty would wait up to
  /// forty seconds per clip. So is anything that is not a single YouTube video,
  /// which [CaptionsFetcher] would refuse anyway. It never throws: the
  /// engine adds the clip whatever happens here.
  Future<void> fetchBeforeAdd(DownloadTask task, MeTubeApi api) async {
    if (task.isBatchMember) return;
    if (!(_ref.read(transcriptsEnabledProvider).valueOrNull ?? false)) return;
    final url = task.effectiveUrl;
    if (PlaylistDetector.isPlaylist(url)) return;
    if (UrlKit.youtubeVideoId(url) == null) return;

    final appLanguage = mtLocalizationsFor(
      _ref.read(settingsProvider).localeCode,
    ).localeName;
    final fetcher = _ref.read(captionsFetcherFactoryProvider)(api);
    for (final language in transcriptLanguages(appLanguage)) {
      final result = await fetcher.fetch(url, language: language);
      _log(
        'captions $language ${result.outcome.name} for $url'
        '${result.detail == null ? '' : ': ${result.detail}'}',
      );
      if (result.transcript case final transcript?) await save(transcript);
      // A server that failed once will likely fail again, and every try
      // holds the download back: the second language is only asked when
      // the first went through.
      final carryOn =
          result.outcome == CaptionsOutcome.fetched ||
          result.outcome == CaptionsOutcome.none;
      if (!carryOn) break;
    }
  }

  /// The languages a clip is kept in: the app's, for reading, then
  /// English, because the terms people search for are so often English
  /// words even in an Arabic talk. One request each, about twenty seconds.
  static List<String> transcriptLanguages(String appLanguage) => [
    appLanguage,
    if (appLanguage != 'en') 'en',
  ];

  Future<void> save(Transcript transcript) async {
    await (await _ref.read(transcriptStoreProvider.future)).write(transcript);
    (await _ref.read(transcriptIndexProvider.future)).add(transcript);
    _ref.read(transcriptsRevisionProvider.notifier).state++;
  }

  /// Everything, as one file's text.
  Future<String> exportAll() async {
    final store = await _ref.read(transcriptStoreProvider.future);
    return TranscriptBundle.encode(await store.readAll().toList());
  }

  /// Writes every transcript in [raw] and returns how many; null when the
  /// file holds none.
  Future<int?> importAll(String raw) async {
    final transcripts = TranscriptBundle.decode(raw);
    if (transcripts == null || transcripts.isEmpty) return null;
    for (final transcript in transcripts) {
      await save(transcript);
    }
    return transcripts.length;
  }

  Future<void> deleteAll() async {
    await (await _ref.read(transcriptStoreProvider.future)).clear();
    (await _ref.read(transcriptIndexProvider.future)).clear();
    _ref.read(transcriptsRevisionProvider.notifier).state++;
  }

  void _log(String message) =>
      unawaited(_ref.read(loggerProvider).log(message, tag: 'transcripts'));
}
