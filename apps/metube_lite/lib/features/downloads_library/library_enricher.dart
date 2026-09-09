import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import 'library_providers.dart';
import 'local_item.dart';
import 'media_probe.dart';

/// **Enriching the local library.**
///
/// The library is built by scanning the folder, so a file migrated from the
/// old Lite arrives with no cover and no dimensions. Before this
/// enrichment, dimensions were learned **only on first play**, so a library
/// of 194 files was entirely outside the shorts path until every clip had
/// been played by hand once, and entirely without thumbnails.
///
/// It works in batches and invalidates the library after each one, so
/// thumbnails appear progressively rather than after the whole scan.
class LibraryEnricher {
  LibraryEnricher(this._ref, {this.batchSize = 20, MediaProbe? probe})
    : _probe = probe ?? const MediaProbe();

  final Ref _ref;
  final MediaProbe _probe;
  final int batchSize;

  /// What has been probed this session: a file that yielded nothing,
  /// because it is corrupt, is not re-probed on every library build. It is
  /// not stored on disk, because retrying after a restart is cheap and what
  /// failed may succeed.
  final Set<String> _seen = {};
  bool _running = false;

  /// Probes whatever is missing a cover or dimensions. Safe to call
  /// repeatedly.
  Future<void> enrich(List<LocalItem> items) async {
    if (_running) return;
    // Probe order equals the default display order, newest first, or the
    // covers appear at the end of the list where nobody is looking.
    // **A cover in the index does not mean a file on disk** (the same cure
    // as Super, 2026-09-07): thumbnails used to be written into `cacheDir`,
    // which Android wipes, so the card stayed empty and was never retried
    // because the index said it had a cover.
    final stale = await _forgetMissingThumbs();
    final pending = [
      for (final item in items)
        if (_needsProbe(item) || stale.contains(item.key)) item,
    ]..sort((a, b) => b.modified.compareTo(a.modified));
    if (pending.isEmpty) return;

    _running = true;
    try {
      for (var i = 0; i < pending.length; i += batchSize) {
        final batch = pending.skip(i).take(batchSize).toList();
        _seen.addAll(batch.map((item) => item.path));
        final results = await _probe.probe([
          for (final item in batch) item.path,
        ]);
        if (await _apply(batch, results)) {
          _ref.invalidate(localMediaProvider);
        }
      }
    } finally {
      _running = false;
    }
  }

  /// Clears from the artwork index every path whose file is gone, and
  /// returns their keys.
  Future<Set<String>> _forgetMissingThumbs() async {
    final artwork = _ref.read(artworkIndexProvider);
    final all = await artwork.readAll();
    final gone = <String>{
      for (final entry in all.entries)
        if (!entry.value.startsWith('http') && !File(entry.value).existsSync())
          entry.key,
    };
    for (final key in gone) {
      await artwork.removeKey(key);
    }
    return gone;
  }

  bool _needsProbe(LocalItem item) =>
      !_seen.contains(item.path) &&
      (item.thumbnail == null ||
          item.duration == null ||
          (!item.isAudio && item.aspectRatio == null));

  /// Writes the results into both indexes under the unified item key. true
  /// means something changed.
  Future<bool> _apply(List<LocalItem> batch, List<ProbedMedia> results) async {
    final byPath = {for (final probed in results) probed.path: probed};
    final shapes = _ref.read(mediaShapeIndexProvider);
    final artwork = _ref.read(artworkIndexProvider);
    var changed = false;

    for (final item in batch) {
      final probed = byPath[item.path];
      if (probed == null || probed.isEmpty) continue;
      // The key is the canonicalUrl when known, otherwise the path: the
      // same rule as the library.
      if (probed.duration != null) {
        await shapes.remember(
          item.key,
          probed.duration!,
          probed.aspectRatio ?? item.aspectRatio ?? 1,
        );
        changed = true;
      }
      if (item.thumbnail == null && probed.thumbPath != null) {
        await artwork.put(item.key, probed.thumbPath!);
        changed = true;
      }
    }
    return changed;
  }
}

final libraryEnricherProvider = Provider<LibraryEnricher>(
  (ref) => LibraryEnricher(ref),
);

/// It runs automatically whenever the library changes, watched once from
/// the app shell. It stops by itself: the next round finds nothing missing
/// and invalidates nothing.
final libraryEnrichmentProvider = Provider<void>((ref) {
  final items = ref.watch(localMediaProvider).valueOrNull;
  if (items == null || items.isEmpty) return;
  unawaited(ref.read(libraryEnricherProvider).enrich(items));
});
