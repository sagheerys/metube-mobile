import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:mt_core/mt_core.dart';
import 'package:mt_core/src/download/history_matcher.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// **Lite's promise, kept across a process death** (audit 2026-09-19).
///
/// Ten ways were found for a file to stay on the server after Lite said it
/// would clean it, and three of them are the same thing: the app stopped
/// watching while the server carried on. Killed from the recents list,
/// stopped by the battery manager — Samsung's Freecess was measured trying
/// twice in a single session — or failed by **one** network blip, since
/// Lite's polling tolerance is zero.
///
/// The tasks lived in memory only, so nobody was left to pull the file or
/// delete the row. These guard the record, and the sweep that acts on it at
/// the next launch.
void main() {
  const url = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';

  late MemoryKeyValueStore store;
  late PendingDownloadsStore pending;
  late FakeApi api;
  late List<String> pulled;

  setUp(() {
    store = MemoryKeyValueStore();
    pending = PendingDownloadsStore(store: store, mutex: PrefsMutex());
    api = FakeApi();
    pulled = [];
  });

  PendingDownload record({
    String id = 't1',
    Set<String> before = const {},
    DateTime? createdAt,
    String? localPath,
  }) => PendingDownload(
    id: id,
    url: url,
    quality: Quality.best,
    createdAt: createdAt ?? DateTime.now(),
    before: before,
    localPath: localPath,
  );

  HistoryItem item({
    ItemStatus status = ItemStatus.completed,
    String? filename = 'clip.mp4',
    String? error,
  }) => HistoryItem(
    id: 'a',
    canonicalUrl: url,
    title: 'clip',
    filename: filename,
    status: status,
    error: error,
  );

  List<String> deletedUrls() => [for (final (ids, _) in api.deletes) ...ids];

  Object? pullError;
  PendingSweeper sweeperOf({
    bool Function()? gate,
    SweepFinished? onFinished,
  }) => PendingSweeper(
    api: api,
    store: pending,
    savePathBuilder: (p, item) => '/media/${item.filename}',
    pullGate: gate,
    onFinished: onFinished,
    transfer: _RecordingTransfer(api: api, pulled: pulled, fail: pullError),
  );

  group('the record survives what the process does not', () {
    test('it is written, read back, and dropped by id', () async {
      await pending.put(record(before: const {'sig'}));

      final all = await pending.readAll();
      expect(all.single.url, url);
      expect(all.single.before, {'sig'});

      await pending.remove('t1');
      expect(await pending.readAll(), isEmpty);
    });

    test('a record older than a week is ignored', () async {
      await pending.put(
        record(createdAt: DateTime.now().subtract(const Duration(days: 8))),
      );

      // Pulling a file somebody forgot they asked for is a surprise, not a
      // service.
      expect(await pending.readAll(), isEmpty);
    });

    test('damaged storage is empty, not an exception at startup', () async {
      await store.setString(PendingDownloadsStore.prefsKey, 'not json at all');

      expect(await pending.readAll(), isEmpty);
    });

    test('putting the same id twice replaces rather than duplicates', () async {
      await pending.put(record());
      await pending.put(record(before: const {'later'}));

      final all = await pending.readAll();
      expect(all, hasLength(1));
      expect(all.single.before, {'later'});
    });

    test(
      'an expired record is purged by the next write, not carried',
      () async {
        await pending.put(
          record(
            id: 'old',
            createdAt: DateTime.now().subtract(const Duration(days: 8)),
          ),
        );
        await pending.put(record(id: 'new'));
        await pending.remove('new');

        // The filter used to live in `readAll` only, and every `put` and
        // `remove` rewrote what it read unfiltered — so the stale record
        // outlived its week for as long as the app was used.
        expect(await store.getString(PendingDownloadsStore.prefsKey), isNull);
      },
    );
  });

  group('the sweep at the next launch', () {
    test('a finished item is pulled and then cleaned off the server', () async {
      await pending.put(record());
      api.historyScript = [
        HistoryResponse(done: [item()]),
      ];

      final outcome = await sweeperOf().sweep();

      expect(outcome['t1'], SweepOutcome.finished);
      expect(pulled, ['clip.mp4'], reason: 'the file reaches the phone');
      expect(deletedUrls(), [url], reason: 'and the server is cleaned');
      expect(await pending.readAll(), isEmpty);
    });

    test('the pull comes first, so a failed delete never loses it', () async {
      await pending.put(record());
      api.historyScript = [
        HistoryResponse(done: [item()]),
      ];
      api.deleteError = const NetworkException('delete failed');
      bool? cleaned;

      final outcome = await sweeperOf(
        onFinished: (item, path, {required serverCleaned}) async =>
            cleaned = serverCleaned,
      ).sweep();

      expect(pulled, ['clip.mp4']);
      expect(
        outcome['t1'],
        SweepOutcome.finished,
        reason: 'the phone has it; cleaning the server is best effort',
      );
      expect(cleaned, isFalse, reason: 'and the caller is told which half');
      // The record stays, now knowing where the file is, so the next
      // launch retries the delete alone.
      expect((await pending.readAll()).single.localPath, '/media/clip.mp4');
    });

    test('a file already on the phone is not pulled twice', () async {
      // The process died during the delete that follows the pull, or the
      // server refused it. Pulling again would leave `video_HHmmss.ext`
      // beside the copy that is already there.
      final onPhone = File(
        '${Directory.systemTemp.path}/mtf_sweep_${DateTime.now().microsecondsSinceEpoch}.mp4',
      )..writeAsBytesSync(const [0]);
      addTearDown(onPhone.deleteSync);
      await pending.put(record(localPath: onPhone.path));
      api.historyScript = [
        HistoryResponse(done: [item()]),
      ];

      final outcome = await sweeperOf().sweep();

      expect(outcome['t1'], SweepOutcome.cleaned);
      expect(pulled, isEmpty);
      expect(deletedUrls(), [url]);
      expect(await pending.readAll(), isEmpty);
    });

    test('what the sweep finished reaches the app like a live '
        'download', () async {
      await pending.put(record());
      api.historyScript = [
        HistoryResponse(done: [item()]),
      ];
      HistoryItem? finished;
      String? at;

      await sweeperOf(
        onFinished: (item, path, {required serverCleaned}) async {
          finished = item;
          at = path;
          expect(serverCleaned, isTrue);
        },
      ).sweep();

      // Without this a recovered file had no canonical URL, no title, no
      // cover and no gallery entry: a stranger in the library.
      expect(finished?.canonicalUrl, url);
      expect(at, '/media/clip.mp4');
    });

    test('two records for one link do not fight over one row', () async {
      // The same link submitted twice, killed before the second ran: one
      // `/history` serves the sweep, and the row the first record took
      // must not be handed to the second — which would pull a file that
      // is no longer there, at every launch, for a week.
      await pending.put(record(id: 'first'));
      await pending.put(record(id: 'second'));
      api.historyScript = [
        HistoryResponse(done: [item()]),
      ];

      final outcome = await sweeperOf().sweep();

      expect(outcome['first'], SweepOutcome.finished);
      expect(outcome['second'], SweepOutcome.gone);
      expect(pulled, ['clip.mp4']);
      expect(await pending.readAll(), isEmpty);
    });

    test('a file this app cannot pull is given up on, not retried', () async {
      await pending.put(record());
      api.historyScript = [
        HistoryResponse(done: [item()]),
      ];
      pullError = const UnsafeFilenameException('..');

      final outcome = await sweeperOf().sweep();

      expect(outcome['t1'], SweepOutcome.unrecoverable);
      expect(deletedUrls(), isEmpty, reason: 'the row is left for the web UI');
      expect(await pending.readAll(), isEmpty, reason: 'no launch-time loop');
    });

    test('an item still downloading is left for next time', () async {
      await pending.put(record());
      api.historyScript = [
        HistoryResponse(
          queue: [item(status: ItemStatus.inProgress, filename: null)],
        ),
      ];

      final outcome = await sweeperOf().sweep();

      expect(outcome['t1'], SweepOutcome.stillRunning);
      expect(await pending.readAll(), hasLength(1));
      expect(deletedUrls(), isEmpty);
    });

    test('a failed item has its row removed and is not pulled', () async {
      await pending.put(record());
      api.historyScript = [
        HistoryResponse(
          done: [item(status: ItemStatus.failed, error: 'blocked')],
        ),
      ];

      final outcome = await sweeperOf().sweep();

      expect(outcome['t1'], SweepOutcome.failed);
      expect(pulled, isEmpty);
      // A leftover error row poisons the next retry of the same link.
      expect(deletedUrls(), [url]);
      expect(await pending.readAll(), isEmpty);
    });

    test('nothing matching means the record goes', () async {
      await pending.put(record());
      api.historyScript = [const HistoryResponse()];

      expect((await sweeperOf().sweep())['t1'], SweepOutcome.gone);
      expect(await pending.readAll(), isEmpty);
    });

    test('an item that existed **before** the add is never adopted', () async {
      // The whole reason the fingerprints are carried across the restart:
      // an older row for the same link — a previous failure, another
      // quality — must not be pulled or deleted in this task's name.
      final existing = item();
      await pending.put(record(before: {HistoryMatcher.signature(existing)}));
      api.historyScript = [
        HistoryResponse(done: [existing]),
      ];

      final outcome = await sweeperOf().sweep();

      expect(outcome['t1'], SweepOutcome.gone);
      expect(pulled, isEmpty);
      expect(deletedUrls(), isEmpty);
    });

    test('a closed Wi-Fi gate defers, and keeps the record', () async {
      await pending.put(record());
      api.historyScript = [
        HistoryResponse(done: [item()]),
      ];

      final outcome = await sweeperOf(gate: () => false).sweep();

      expect(outcome['t1'], SweepOutcome.deferred);
      expect(pulled, isEmpty);
      expect(deletedUrls(), isEmpty);
      expect(await pending.readAll(), hasLength(1), reason: 'not lost');
    });

    test('an unreachable server is "not this time", not a crash', () async {
      await pending.put(record());
      api.onHistoryFetch = (_) => throw const NetworkException('off');

      expect(await sweeperOf().sweep(), isEmpty);
      expect(
        await pending.readAll(),
        hasLength(1),
        reason: 'the record waits for a launch with a network',
      );
    });

    test('no records means no request at all', () async {
      expect(await sweeperOf().sweep(), isEmpty);
      expect(api.historyCalls, 0);
    });
  });
}

/// A [Transfer] that records what it was asked for instead of touching the
/// network or the disk.
class _RecordingTransfer implements Transfer {
  _RecordingTransfer({required this.api, required this.pulled, this.fail});

  @override
  final MeTubeApi api;
  final List<String> pulled;
  final Object? fail;

  @override
  int get retries => 1;

  @override
  List<Duration> get backoff => const [];

  @override
  Future<String> pull({
    required String serverFilename,
    required String savePath,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (fail != null) throw fail!;
    pulled.add(serverFilename);
    return savePath;
  }
}
