import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import 'batch_offline_saver.dart';

/// Playlist preview: YouTube through InnerTube directly (the ready-made
/// package returned zero items, reported 2026-09-02) and SoundCloud through
/// the fragile, isolated resolver. Any failure shows a message and breaks
/// nothing.
final playlistPreviewProvider = FutureProvider.family<PlaylistPreview?, String>(
  (ref, url) async {
    final preview = switch (PlaylistDetector.detect(url)) {
      PlaylistKind.youtube => await YoutubePlaylistResolver().resolve(url),
      PlaylistKind.soundcloud => await SoundCloudResolver().resolveSet(url),
      PlaylistKind.none => null,
    };
    if (preview == null) {
      // The reason for an empty screen must leave a trace rather than
      // evaporate.
      unawaited(
        ref
            .read(loggerProvider)
            .error('playlist resolve failed', tag: 'playlist'),
      );
    }
    return preview;
  },
);

/// Enqueues the selection into the engine's queue (rule 3, step 2): the
/// items go behind any single item in flight and are marked as batch
/// members.
final batchSubmitterProvider = Provider((ref) => BatchSubmitter(ref));

class BatchSubmitter {
  const BatchSubmitter(this._ref);

  final Ref _ref;

  /// Returns how many were actually enqueued (0 means no server
  /// configured).
  ///
  /// **[groupName] collects the batch into one saved playlist** (asked
  /// 2026-09-02): before it, the items of a single course scattered through
  /// the library with no link between them. Collection happens as each item
  /// completes, in source order.
  ///
  /// **[saveToDevice]** applies "available offline" to every member that
  /// completes; the original stays on the server, so rule 2 holds.
  int submit(
    List<String> urls,
    Quality quality, {
    String? groupName,
    bool saveToDevice = false,
  }) {
    final engine = _ref.read(downloadEngineProvider);
    if (engine == null || urls.isEmpty) return 0;
    final ids = [
      for (final url in urls)
        engine.submit(url, quality, isBatchMember: true).id,
    ];
    if (groupName != null && groupName.trim().isNotEmpty) {
      unawaited(_ref.read(batchCollectorProvider).begin(groupName.trim(), ids));
    }
    if (saveToDevice) _ref.read(batchOfflineSaverProvider).want(ids);
    return ids.length;
  }
}
