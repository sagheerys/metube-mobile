import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show ServerStreamEndpoint;

import '../../di.dart';
import '../shared/error_report.dart';
import 'library_models.dart';
import 'library_providers.dart';
import 'media_probe.dart';

/// **Enriching Super's library.**
///
/// A real server returns no `thumbnail` field for any item (zero out of
/// 252), and dimensions were learned **only on first play**, so the entire
/// server library had no covers and fell outside the shorts path (field
/// report: "reels only works if you play it once first, and the thumbnails
/// do not appear").
///
/// The source is the local copy when there is one, which is faster and
/// needs no network, and otherwise **the server stream**: the native
/// reader reads the header with range requests and never downloads the
/// file.
class LibraryEnricher {
  LibraryEnricher(this._ref, {this.batchSize = 8, MediaProbe? probe})
    : _probe = probe ?? const MediaProbe();

  final Ref _ref;
  final MediaProbe _probe;

  /// A smaller batch than Lite's: every item here may mean a network trip.
  final int batchSize;

  final Set<String> _seen = {};
  bool _running = false;

  Future<void> enrich(List<LibraryItem> items) async {
    if (_running) return;
    final endpoint = _ref.read(playbackResolverProvider).endpoint;
    final headers = _ref.read(apiClientProvider)?.streamingHeaders ?? const {};

    // **A cover in the index does not mean a file on disk**: thumbnails
    // used to be written into `cacheDir`, which Android wipes under storage
    // pressure, so the cards stayed empty **and were never retried**,
    // because `_needsProbe` saw a registered cover.
    final stale = await _forgetMissingThumbs();

    // **Probe order equals display order** (caught on the emulator
    // 2026-09-02): it probed in `/history` order while the library shows
    // newest first, so minutes passed and 55 covers were ready with none of
    // them at the top of the screen. And local before network always:
    // reading a file on disk is cheaper than a trip to the server.
    final candidates =
        [
          for (final item in items)
            if (_needsProbe(item) || stale.contains(item.canonicalUrl)) item,
        ]..sort((a, b) {
          final localFirst =
              (b.localPath != null ? 1 : 0) - (a.localPath != null ? 1 : 0);
          if (localFirst != 0) return localFirst;
          final at = a.timestamp, bt = b.timestamp;
          if (at == null || bt == null) return 0;
          return bt.compareTo(at); // newest first
        });

    // **The failure memory** (defect 2026-09-07): an item that failed
    // recently is not re-probed. One dead record was consuming 80 seconds
    // of every session.
    final failures = _ref.read(probeFailureIndexProvider);
    final cooling = await failures.readAll();

    // **A cover in the index does not mean a file on disk**: thumbnails
    // used to be written into `cacheDir`, which Android wipes under storage
    // pressure, so the cards stayed empty **and were never retried**,
    // because `_needsProbe` saw a registered cover.
    final pending = <ProbeRequest>[];
    for (final item in candidates) {
      if (failures.isCoolingDown(cooling, item.canonicalUrl)) continue;
      final request = _requestFor(item, endpoint);
      if (request == null) continue;
      // **A URL whose liveness we have not confirmed is never handed to the
      // platform**: `MediaMetadataRetriever` retries a dead URL ten times
      // on an 8s timeout and freezes the queue, while one byte from us
      // settles it in a fraction of a second.
      if (request.url != null && !await _serverHasFile(item)) {
        await _recordFailure(item.canonicalUrl, 'file missing on server');
        continue;
      }
      pending.add(request);
    }
    // The queue counter in the log: "no thumbnails" has three causes that
    // look alike (no candidates, all cooling down, all without a filename),
    // and without this line nobody can tell them apart.
    unawaited(
      _ref
          .read(loggerProvider)
          .log(
            'probe queue: ${pending.length} of ${candidates.length} '
            '(cooling ${cooling.length})',
            tag: 'library',
          ),
    );
    if (pending.isEmpty) return;

    _running = true;
    try {
      for (var i = 0; i < pending.length; i += batchSize) {
        final batch = pending.skip(i).take(batchSize).toList();
        _seen.addAll(batch.map((r) => r.key));
        final results = await _probe.probe(batch, headers: headers);
        if (await _apply(results)) {
          _ref.invalidate(libraryItemsProvider);
        }
      }
    } finally {
      _running = false;
    }
  }

  bool _needsProbe(LibraryItem item) =>
      !_seen.contains(item.canonicalUrl) &&
      (item.thumbnail == null ||
          item.duration == null ||
          (!item.isAudio && item.aspectRatio == null));

  /// Local first, otherwise the streaming URL. An item with neither is not
  /// probed.
  ProbeRequest? _requestFor(LibraryItem item, ServerStreamEndpoint endpoint) {
    if (item.localPath != null) {
      return ProbeRequest(key: item.canonicalUrl, path: item.localPath);
    }
    final filename = item.serverFilename;
    if (filename == null) return null;
    try {
      return ProbeRequest(
        key: item.canonicalUrl,
        url: endpoint.buildUrl(filename),
      );
    } on UnsafeFilenameException {
      // Rule 9: a URL is never built for a malicious filename.
      return null;
    }
  }

  /// Clears from the artwork index every path whose file is gone, and
  /// returns their keys so they are probed again in the same round.
  Future<Set<String>> _forgetMissingThumbs() async {
    final artwork = _ref.read(artworkIndexProvider);
    final all = await artwork.readAll();
    final gone = <String>{
      for (final entry in all.entries)
        // Network URLs (ytimg) are not files and are left alone.
        if (!entry.value.startsWith('http') && !File(entry.value).existsSync())
          entry.key,
    };
    for (final key in gone) {
      await artwork.removeKey(key);
    }
    if (gone.isNotEmpty) {
      unawaited(
        _ref
            .read(loggerProvider)
            .log('thumbs vanished from disk: ${gone.length}', tag: 'library'),
      );
    }
    return gone;
  }

  /// Records the reason in the diagnostic log **and defers** the retry by a
  /// day.
  Future<bool> _serverHasFile(LibraryItem item) async {
    final api = _ref.read(apiClientProvider);
    final filename = item.serverFilename;
    if (api == null || filename == null) return false;
    return api.fileExists(filename);
  }

  /// Records the reason in the diagnostic log **and defers** the retry by a
  /// day.
  Future<void> _recordFailure(String canonicalUrl, String reason) async {
    // No explicit error and no data: a codec the platform did not
    // understand,
    // which is a failure too.
    await logErrorOnce(
      _ref.read(loggerProvider),
      'probe',
      '$reason ($canonicalUrl)',
      tag: 'library',
    );
    await _ref
        .read(probeFailureIndexProvider)
        .put(canonicalUrl, DateTime.now());
  }

  Future<bool> _apply(List<ProbedMedia> results) async {
    final shapes = _ref.read(mediaShapeIndexProvider);
    final artwork = _ref.read(artworkIndexProvider);
    final existing = await artwork.readAll();
    var changed = false;

    for (final probed in results) {
      if (probed.error != null) {
        await _recordFailure(probed.key, probed.error!);
      }
      if (probed.isEmpty) {
        // No explicit error and no data: a codec the platform did not
        // understand, which is a failure too.
        if (probed.error == null) {
          await _recordFailure(probed.key, 'probe returned nothing');
        }
        continue;
      }
      if (probed.duration != null) {
        await shapes.remember(
          probed.key,
          probed.duration!,
          probed.aspectRatio ?? 1,
        );
        changed = true;
      }
      // We never overwrite an existing cover; a derived YouTube cover is
      // more accurate than a frame capture.
      if (probed.thumbPath != null && existing[probed.key] == null) {
        await artwork.put(probed.key, probed.thumbPath!);
        changed = true;
      }
    }
    return changed;
  }
}

final libraryEnricherProvider = Provider<LibraryEnricher>(
  (ref) => LibraryEnricher(ref),
);

/// It runs whenever the library changes and stops by itself once nothing is
/// missing.
final libraryEnrichmentProvider = Provider<void>((ref) {
  final items = ref.watch(libraryItemsProvider).valueOrNull;
  if (items == null || items.isEmpty) return;
  unawaited(ref.read(libraryEnricherProvider).enrich(items));
});
