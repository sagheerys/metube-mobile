import 'dart:async';
import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// **The engine's half of the recovery** (audit 2026-09-19): writing the
/// record at the moments that matter, and dropping it only at an end that
/// nothing needs to finish.
///
/// The record is what [PendingSweeper] acts on at the next launch. A record
/// left behind after a completed or cancelled task is worse than no record
/// at all: the next launch would pull, or delete, something nobody is
/// waiting for. And a record dropped on a network failure is worse still —
/// that failure is the very case the record was written for.
void main() {
  const url = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';

  late FakeApi api;
  late PendingDownloadsStore pending;
  late Directory temp;

  setUp(() {
    api = FakeApi();
    pending = PendingDownloadsStore(
      store: MemoryKeyValueStore(),
      mutex: PrefsMutex(),
    );
    temp = Directory.systemTemp.createTempSync('mtf_pending');
  });

  tearDown(() => temp.deleteSync(recursive: true));

  HistoryItem done({String? error}) => HistoryItem(
    id: 'a',
    canonicalUrl: url,
    title: 'clip',
    filename: 'clip.mp4',
    status: error == null ? ItemStatus.completed : ItemStatus.failed,
    error: error,
  );

  DownloadEngine engineOf({
    DeletePolicy policy = DeletePolicy.keepOnServer,
    bool pullToDevice = false,
    int maxPollAttempts = MTConstants.maxPollAttempts,
    Duration pollInterval = Duration.zero,
  }) => DownloadEngine(
    api: api,
    policy: policy,
    pullToDevice: pullToDevice,
    pending: pending,
    pollInterval: pollInterval,
    maxPollAttempts: maxPollAttempts,
    savePathBuilder: (task, name) => '${temp.path}/$name',
  );

  /// The record is written without being awaited, on purpose: a download
  /// must never wait on storage. So the tests wait for the write instead of
  /// the pipeline waiting for it.
  Future<List<PendingDownload>> settledRecords() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return pending.readAll();
  }

  Future<DownloadTask> finished(DownloadEngine engine) => engine.updates
      .firstWhere((t) => t.isFinished)
      .timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('the task never finished'),
      );

  test('the record exists before the add, with the fingerprints', () async {
    final existing = done();
    api.historyScript = [
      HistoryResponse(done: [existing]),
      HistoryResponse(done: [existing]),
    ];
    // Captured, not asserted, inside the hook: an `expect` thrown there is
    // caught by the engine as a task failure and the test passes anyway.
    List<PendingDownload>? atAdd;
    api.beforeAdd = () async => atAdd = await settledRecords();
    final engine = engineOf();
    addTearDown(engine.dispose);

    engine.submit(url, Quality.best);
    await finished(engine);

    // The moment most likely to be interrupted is the one about to begin:
    // the server is about to start working. The record must already exist,
    // and carry what was there before, or the sweep adopts the older row.
    expect(atAdd, hasLength(1));
    expect(atAdd!.single.before, isNotEmpty);
  });

  test('a task still in the queue has no record', () async {
    // The server has not been asked, so there is nothing to finish. A
    // record without fingerprints would let the sweep adopt **any** row
    // for the link — on a shared server, somebody else's copy — and pull
    // it and delete it.
    final hold = Completer<void>();
    api.beforeAdd = () => hold.future;
    final engine = engineOf();
    addTearDown(engine.dispose);

    engine.submit(url, Quality.best);
    final second = engine.submit('$url&second', Quality.best);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final records = await settledRecords();
    expect(engine.taskById(second.id)!.phase, TaskPhase.queued);
    expect(records.where((r) => r.id == second.id), isEmpty);
    hold.complete();
  });

  test('a completed task leaves no record behind', () async {
    api.historyScript = [
      const HistoryResponse(),
      HistoryResponse(done: [done()]),
    ];
    final engine = engineOf();
    addTearDown(engine.dispose);

    engine.submit(url, Quality.best);
    final task = await engine.updates.firstWhere(
      (t) => t.phase == TaskPhase.completed,
    );

    expect(task.phase, TaskPhase.completed);
    expect(await settledRecords(), isEmpty);
  });

  test('a task the server refused leaves no record behind', () async {
    api.historyScript = [
      const HistoryResponse(),
      HistoryResponse(done: [done(error: 'blocked')]),
    ];
    final engine = engineOf();
    addTearDown(engine.dispose);

    engine.submit(url, Quality.best);
    await engine.updates.firstWhere((t) => t.phase == TaskPhase.failed);

    // A refusal is final; a record kept here would have the next launch
    // chase a download that was abandoned.
    expect(await settledRecords(), isEmpty);
  });

  test('a task that outlived the polling ceiling keeps its record', () async {
    // The server is still working when the engine gives up waiting, and
    // it finishes the file an hour later. The record is the only thing
    // that gets that file pulled and cleaned — dropping it here defeated
    // the whole feature on exactly the failures it was written for.
    api.historyScript = [const HistoryResponse()];
    final engine = engineOf(maxPollAttempts: 2);
    addTearDown(engine.dispose);

    engine.submit(url, Quality.best);
    final task = await finished(engine);

    expect(task.error, isA<PollTimeoutException>());
    expect(await settledRecords(), hasLength(1));
  });

  test('a delete the server refused keeps the record, with the path', () async {
    api.historyScript = [
      const HistoryResponse(),
      HistoryResponse(done: [done()]),
    ];
    api.deleteError = const NetworkException('cloudflare hiccup');
    final engine = engineOf(
      policy: DeletePolicy.autoDelete,
      pullToDevice: true,
    );
    addTearDown(engine.dispose);

    engine.submit(url, Quality.best);
    final task = await finished(engine);

    expect(task.phase, TaskPhase.completed, reason: 'the file is safe');
    expect(task.serverCleanupFailed, isTrue, reason: 'and the app is told');
    final record = (await settledRecords()).single;
    expect(record.canonicalUrl, url);
    expect(
      record.localPath,
      task.localPath,
      reason: 'so the next launch cleans the server and pulls nothing',
    );
  });

  test('a task cancelled while queued leaves no record behind', () async {
    api.historyScript = [const HistoryResponse()];
    final engine = engineOf();
    addTearDown(engine.dispose);

    // Two tasks so the second is still waiting its turn when cancelled:
    // concurrency is one.
    engine.submit(url, Quality.best);
    final second = engine.submit('$url&second', Quality.best);
    engine.cancel(second.id);
    // The phase is read rather than awaited on the stream: cancelling a
    // queued task emits **synchronously**, so a listener attached
    // afterwards would wait forever for an event that already happened.
    final records = await settledRecords();
    expect(engine.taskById(second.id)!.phase, TaskPhase.cancelled);
    expect(records.where((r) => r.id == second.id), isEmpty);
  });

  test('disposing the engine mid-task is not a cancellation', () async {
    // The engine goes when the server settings change; the server does
    // not. Its cleanup refuses to run on a disposed engine, so the record
    // is the only thing left that knows the download is still running.
    api.historyScript = [const HistoryResponse()];
    // A real interval, so the task is still polling when the engine goes
    // (at zero it would have hit the ceiling first).
    final engine = engineOf(pollInterval: const Duration(milliseconds: 10));

    engine.submit(url, Quality.best);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    await engine.dispose();
    // The poll loop notices the disposal on its next tick, not at once.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await settledRecords(), hasLength(1));
  });

  test(
    'an app that passes no store keeps working, and writes nothing',
    () async {
      api.historyScript = [
        const HistoryResponse(),
        HistoryResponse(done: [done()]),
      ];
      // Super's case: nothing to reconcile, so nothing is recorded.
      final engine = DownloadEngine(
        api: api,
        policy: DeletePolicy.keepOnServer,
        pullToDevice: false,
        pollInterval: Duration.zero,
        savePathBuilder: (task, name) => '/media/$name',
      );
      addTearDown(engine.dispose);

      engine.submit(url, Quality.best);
      final task = await engine.updates.firstWhere((t) => t.isFinished);

      expect(task.phase, TaskPhase.completed);
      expect(await settledRecords(), isEmpty);
    },
  );
}
