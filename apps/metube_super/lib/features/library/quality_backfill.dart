import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di.dart';
import 'library_models.dart';
import 'library_providers.dart';
import 'quality_cache.dart';

/// Reads, in the background, the quality of every library item that does
/// not have one stored yet.
///
/// Reading ahead on completion covers downloads added from this app, but
/// not the library that existed before, nor what a subscription or the
/// MeTube web page downloads. This walks those too, one item at a time
/// with a pause between them, so the details sheet opens with the answer
/// already there.
///
/// **Only items the library enricher has already read are candidates**,
/// meaning their duration is known. That proves the file exists and the
/// platform can parse it. Handing an unchecked server URL to the platform
/// reader is what froze the probe queue for 80 seconds when one file had
/// been deleted from the server's disk.
class QualityBackfill {
  QualityBackfill(this._ref, {this.pause = const Duration(seconds: 2)});

  final Ref _ref;

  /// The gap between two reads: this is a courtesy task and must never
  /// compete with playback for the server.
  final Duration pause;

  /// Tried this run, answered or not, so a file that cannot be parsed is
  /// not asked again on every library refresh.
  final Set<String> _tried = {};
  bool _running = false;
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  Future<void> run(List<LibraryItem> items) async {
    if (_running || _cancelled) return;
    _running = true;
    try {
      final index = _ref.read(mediaQualityIndexProvider);
      final known = await index.readAll();
      final failures = _ref.read(probeFailureIndexProvider);
      final cooling = await failures.readAll();
      final serverDown = _ref.read(libraryServerErrorProvider) != null;

      final candidates = [
        for (final item in items)
          if (!known.containsKey(item.canonicalUrl) &&
              !_tried.contains(item.canonicalUrl) &&
              item.duration != null &&
              !failures.isCoolingDown(cooling, item.canonicalUrl) &&
              (item.localPath != null ||
                  (item.serverFilename != null && !serverDown)))
            item,
      ]..sort(_localThenNewest);

      final reader = _ref.read(qualityReaderProvider);
      for (final item in candidates) {
        if (_cancelled) return;
        _tried.add(item.canonicalUrl);
        try {
          final quality = await reader.read(
            localPath: item.localPath,
            serverFilename: item.serverFilename,
          );
          if (_cancelled) return;
          if (quality != null) await index.remember(item.canonicalUrl, quality);
        } on Object {
          // Left unknown: the sheet reads it when it first opens.
        }
        await Future<void>.delayed(pause);
      }
    } finally {
      _running = false;
    }
  }

  /// The order the library shows, local copies first: a file on the phone
  /// needs no network at all.
  static int _localThenNewest(LibraryItem a, LibraryItem b) {
    final local = (b.localPath != null ? 1 : 0) - (a.localPath != null ? 1 : 0);
    if (local != 0) return local;
    final at = a.timestamp, bt = b.timestamp;
    if (at == null || bt == null) return 0;
    return bt.compareTo(at);
  }
}

final qualityBackfillProvider = Provider<QualityBackfill>((ref) {
  final backfill = QualityBackfill(ref);
  ref.onDispose(backfill.cancel);
  return backfill;
});

/// Runs whenever the library changes, like the enricher, and finds nothing
/// to do once every item's quality is stored.
final qualityBackfillRunProvider = Provider<void>((ref) {
  final items = ref.watch(libraryItemsProvider).valueOrNull;
  if (items == null || items.isEmpty) return;
  unawaited(ref.read(qualityBackfillProvider).run(items));
});
