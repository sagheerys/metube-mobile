import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart' show cachedCoverFetcher;

import '../../di.dart';
import '../../features/library/artwork.dart';
import '../library_data.dart';
import 'cover_enricher.dart';
import 'cover_shrink.dart';
import 'mp4_cover.dart';

/// Where found covers are kept: `%LOCALAPPDATA%\MeTube Ember\cache\
/// embedded`. Overridden in main; null (tests) turns the search off.
final coverFolderProvider = Provider<Directory?>((ref) => null);

/// Takes one frame from a video, given where it is and the headers to
/// read it with. Overridden in main with the engine's; null (tests) leaves
/// videos alone.
final frameGrabProvider =
    Provider<
      Future<Uint8List?> Function(String url, Map<String, String> headers)?
    >((ref) => null);

final probeFailureIndexProvider = Provider(
  (ref) => ProbeFailureIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// Reads a clip's file **on the server, and only there**, with the
/// server's own headers, so its password never reaches another host.
RangeReader serverRangeReader(MeTubeApiClient api, String serverFilename) {
  final uri = Uri.parse(api.downloadUrl(serverFilename));
  return (start, length) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      api.streamingHeaders.forEach(request.headers.set);
      // This client re-sends custom headers to whatever host a redirect
      // names, so a Cloudflare pair must not follow one.
      request.followRedirects = api.config.accessHeaders.isEmpty;
      request.headers.set(
        HttpHeaders.rangeHeader,
        'bytes=$start-${start + length - 1}',
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.partialContent &&
          response.statusCode != HttpStatus.ok) {
        throw HttpException('status ${response.statusCode}', uri: uri);
      }
      // A server that ignores ranges sends the whole file: take what was
      // asked for and stop listening.
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytes.add(chunk);
        if (bytes.length >= length) break;
      }
      final all = bytes.takeBytes();
      return all.length > length ? Uint8List.sublistView(all, 0, length) : all;
    } finally {
      client.close(force: true);
    }
  };
}

/// Where a video's frame is taken from: **a copy on this computer is read
/// in place, with no credentials**; otherwise the server's own file with
/// the server's own headers, and nothing else.
FrameFor videoFrameFor(
  Future<Uint8List?> Function(String url, Map<String, String> headers) grab,
  MeTubeApiClient api,
) => (item) async {
  if (item.localPath case final path? when File(path).existsSync()) {
    return grab(path, const {});
  }
  final name = item.serverFilename;
  if (!item.onServer || name == null) return null;
  return grab(api.downloadUrl(name), api.streamingHeaders);
};

/// Looks for missing covers in the background whenever the library is
/// read, one clip at a time so the library never waits, and shows what it
/// found every few covers and at the end. Watched by the shell.
final coverEnrichmentProvider = Provider<void>((ref) {
  final folder = ref.watch(coverFolderProvider);
  final api = ref.watch(apiClientProvider);
  if (folder == null || api == null) return;
  final enricher = CoverEnricher(
    artwork: ref.watch(artworkIndexProvider),
    failures: ref.watch(probeFailureIndexProvider),
    folder: folder,
    readerFor: (item) {
      final name = item.serverFilename;
      return item.onServer && name != null
          ? serverRangeReader(api, name)
          : null;
    },
    frameFor: switch (ref.watch(frameGrabProvider)) {
      final grab? => videoFrameFor(grab, api),
      null => null,
    },
  );
  // The app always names its cover cache; without one (a test) nothing is
  // fetched.
  final cache = ref.watch(artworkCacheProvider);
  final CoverFetcher fetch = cache == null
      ? (_) async => const FetchedCover.failed()
      : cachedCoverFetcher(cache, api.imageHeadersFor);
  var running = false;
  var stopped = false;
  ref.onDispose(() => stopped = true);

  Future<void> run(List<LibraryItem> items) async {
    if (running) return;
    running = true;
    var found = 0;
    var shown = 0;
    var missed = 0;
    // A kept file looks the same as the online cover, but the library
    // should read it from now on.
    var keptAny = false;
    try {
      // Black covers taken before frames were checked, once: forgotten
      // here, they are taken again below from further in.
      await forgetDarkCovers(folder, ref.read(artworkIndexProvider));
      // Gone while that ran (the window closed): nothing is left to read.
      if (stopped) return;
      // Online covers kept as files first, so a clip taken down at its
      // source keeps its face; one already gone gets a picture from the
      // clip's own file instead.
      final byUrl = {for (final item in items) item.canonicalUrl: item};
      final keeper = CoverKeeper(
        kept: ref.read(keptCoverIndexProvider),
        failures: ref.read(probeFailureIndexProvider),
        folder: folder,
        shrink: shrinkCover,
        fetch: fetch,
        fallback: (url) async => switch (byUrl[url]) {
          final item? => enricher.pictureOf(item),
          null => null,
        },
      );
      for (final url in await keeper.candidates({
        for (final item in items) item.canonicalUrl: item.thumbnail,
      })) {
        if (stopped) return;
        final outcome = await keeper.keep(url, byUrl[url]!.thumbnail!);
        if (outcome == CoverOutcome.failed) {
          // Offline, most likely: the rest waits for the next reading.
          if (++missed >= _missesBeforeRest) break;
          continue;
        }
        missed = 0;
        if (outcome == CoverOutcome.replaced) found++;
        if (outcome == CoverOutcome.kept) keptAny = true;
        if (found - shown >= _showEvery) {
          shown = found;
          ref.invalidate(libraryItemsProvider);
        }
      }
      missed = 0;
      for (final item in await enricher.candidates(items)) {
        if (stopped) return;
        if (await enricher.enrich(item)) {
          found++;
          missed = 0;
          // Hundreds of videos take minutes: show them as they come.
          if (found - shown >= _showEvery) {
            shown = found;
            ref.invalidate(libraryItemsProvider);
          }
        } else if (++missed >= _missesBeforeRest) {
          // The server has likely gone away; marking every clip after this
          // as having no cover would hide them all for a day.
          break;
        }
      }
      // Covers kept before they were made card-sized, once.
      if (!stopped) await shrinkKeptCovers(folder);
    } finally {
      running = false;
    }
    if ((found > shown || keptAny) && !stopped) {
      ref.invalidate(libraryItemsProvider);
    }
  }

  ref.listen(libraryItemsProvider, (_, next) {
    // Newest first, as the library opens: hundreds of videos take minutes,
    // and the ones on screen should not come last.
    if (next.valueOrNull case final items?) {
      unawaited(run(buildLibraryView(items)));
    }
  }, fireImmediately: true);
});

const _showEvery = 12;
const _missesBeforeRest = 6;
