import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

import '../../di.dart';
import '../library/library_models.dart';
import '../library/library_providers.dart';
import 'transcripts_state.dart';

/// Reads, in the background, the subtitle files the server wrote beside
/// the clips that have no transcript yet (see [SidecarReader]).
///
/// The transcript fetched before an add covers the clips added from this
/// app, and nothing else: what a subscription brings, what the web page
/// downloads, a batch. A server set to write subtitles has a file beside
/// each of those, and this walks the library for them, one clip at a time
/// with a pause between, so a clip that arrived while the phone slept is
/// searchable minutes after the library next refreshes.
///
/// It runs only while "Search inside clips" is on, like every other use of
/// the transcripts, and asks about each file once: a miss is remembered
/// across launches, a server that cannot be reached ends the run without
/// remembering anything.
class SidecarBackfill {
  SidecarBackfill(this._ref, {this.pause = const Duration(seconds: 2)});

  final Ref _ref;

  /// Between two clips: a courtesy task that must never compete with
  /// playback for the server.
  final Duration pause;

  /// Tried this run, so a server error does not have the same clip asked
  /// again on every refresh until the next launch.
  final Set<String> _tried = {};
  bool _running = false;
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  Future<void> run(List<LibraryItem> items) async {
    if (_running || _cancelled) return;
    if (!(_ref.read(transcriptsEnabledProvider).valueOrNull ?? false)) return;
    final api = _ref.read(sidecarApiProvider);
    if (api == null || _ref.read(libraryServerErrorProvider) != null) return;
    _running = true;
    try {
      final index = await _ref.read(transcriptIndexProvider.future);
      final misses = _ref.read(sidecarMissIndexProvider);
      final missed = await misses.readAll();
      final candidates = [
        for (final item in items)
          if (item.serverFilename case final filename?)
            if (item.onServer &&
                !index.contains(item.canonicalUrl) &&
                !_tried.contains(item.canonicalUrl) &&
                !SidecarMissIndex.covers(missed, item.canonicalUrl, filename))
              item,
      ]..sort(_newestFirst);
      if (candidates.isEmpty) return;

      final service = _ref.read(transcriptsServiceProvider);
      final SidecarListing? listing;
      try {
        listing = await _listing(api);
      } on MTApiException {
        return; // unreachable: nothing is asked, nothing marked missing
      }
      if (_cancelled) return;
      final reader = SidecarReader(api, listing: listing);
      for (final item in candidates) {
        if (_cancelled) return;
        _tried.add(item.canonicalUrl);
        var found = false;
        for (final language in service.languages) {
          final result = await reader.read(
            canonicalUrl: item.canonicalUrl,
            filename: item.serverFilename!,
            language: language,
          );
          if (_cancelled) return;
          switch (result.outcome) {
            case SidecarOutcome.found:
              found = true;
              await service.save(result.transcript!);
            case SidecarOutcome.none:
              break;
            case SidecarOutcome.failed:
              // The server is in trouble; the rest can wait for a refresh
              // after it recovers, and nothing is recorded as missing.
              return;
          }
        }
        if (!found) await misses.put(item.canonicalUrl, item.serverFilename!);
        await Future<void>.delayed(pause);
      }
    } finally {
      _running = false;
    }
  }

  /// The folder's names, read once per run so each clip's files are found
  /// whatever their track suffix. A server that does not list its folder
  /// leaves the reader to the plain names; any other failure is the
  /// caller's to end the run on.
  Future<SidecarListing?> _listing(MeTubeApi api) async {
    try {
      return SidecarListing.parse(await api.fetchDownloadIndex());
    } on NoApiException {
      return null;
    }
  }

  /// What just arrived is what the user is most likely to search for.
  static int _newestFirst(LibraryItem a, LibraryItem b) {
    final at = a.timestamp, bt = b.timestamp;
    if (at == null || bt == null) return 0;
    return bt.compareTo(at);
  }
}

/// The server the files are read from: the app's client, behind the
/// interface so a test can stand in a fake.
final sidecarApiProvider = Provider<MeTubeApi?>(
  (ref) => ref.watch(apiClientProvider),
);

final sidecarMissIndexProvider = Provider(
  (ref) => SidecarMissIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

final sidecarBackfillProvider = Provider<SidecarBackfill>((ref) {
  final backfill = SidecarBackfill(ref);
  ref.onDispose(backfill.cancel);
  return backfill;
});

/// Runs whenever the library changes, and again when the transcripts are
/// turned on, so a server that writes subtitles fills the search within
/// minutes of either.
final sidecarBackfillRunProvider = Provider<void>((ref) {
  final enabled = ref.watch(transcriptsEnabledProvider).valueOrNull ?? false;
  final items = ref.watch(libraryItemsProvider).valueOrNull;
  if (!enabled || items == null || items.isEmpty) return;
  unawaited(ref.read(sidecarBackfillProvider).run(items));
});
