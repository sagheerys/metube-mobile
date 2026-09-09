import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import '../library/library_actions.dart';

/// **Saving a batch to the device** (requested 2026-09-03: "the SoundCloud
/// album does not download to the device, only to the server").
///
/// Super adds to the server and does not pull (rule 2), and pulling there
/// is a separate action called "available offline". This class **does not
/// breach that rule**: it applies the same action to every batch member
/// that completes, when the owner asks for it explicitly with a switch on
/// the batch screen. The original stays on the server as the rule says.
///
/// **Sequential rather than parallel:** an album of 400 clips means 400
/// downloads, and starting them together chokes the network and fails some
/// of them on a timeout.
class BatchOfflineSaver {
  BatchOfflineSaver({required this.pull, this.onError});

  /// The actual pull, injected so the class stays testable without a
  /// network.
  final Future<void> Function(DownloadTask task) pull;
  final void Function(Object error)? onError;

  /// The pull chain: every item waits for the one before it.
  final Set<String> _wanted = {};

  /// For tests: waits until the queue is empty.
  Future<void> _chain = Future<void>.value();

  /// For tests: waits until the queue is empty.
  Future<void> get idle => _chain;

  int get pendingCount => _wanted.length;

  /// A member that fell away, failed or cancelled, is not waited on, or the
  /// ids leak.
  void want(Iterable<String> taskIds) => _wanted.addAll(taskIds);

  /// A member completed, so it takes its turn in the pull queue.
  void forget(String taskId) => _wanted.remove(taskId);

  /// A member completed, so it takes its turn in the pull queue.
  void onFinished(DownloadTask task) {
    if (!_wanted.remove(task.id)) return;
    if ((task.canonicalUrl ?? '').isEmpty) return;
    _chain = _chain.then((_) => _guarded(task));
  }

  /// **A failed pull does not bring down the rest of the album**: the item
  /// stays on the server and can be pulled later with one tap of "available
  /// offline".
  Future<void> _guarded(DownloadTask task) async {
    try {
      await pull(task);
    } on Object catch (error) {
      onError?.call(error);
    }
  }
}

final batchOfflineSaverProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  return BatchOfflineSaver(
    pull: (task) async {
      await ref
          .read(libraryActionsProvider)
          .pullToDevice(
            canonicalUrl: task.canonicalUrl!,
            serverFilename: task.serverFilename,
            title: task.title ?? task.canonicalUrl!,
            thumbnail: task.thumbnail,
          );
      unawaited(
        logger.log(
          'batch saved to device ${task.title ?? ''}',
          tag: 'download',
        ),
      );
    },
    onError: (error) => unawaited(
      logger.error('batch save to device failed: $error', tag: 'download'),
    ),
  );
});
