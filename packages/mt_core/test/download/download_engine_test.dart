import 'dart:async';
import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

void main() {
  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mtf_engine_');
  });
  tearDown(() => tempDir.delete(recursive: true));

  const inputUrl = 'https://youtu.be/dQw4w9WgXcQ';
  const canonical = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

  Map<String, dynamic> doneItem({String? filename = 'قناة.dQw4.mp4'}) => {
    'id': 'dQw4w9WgXcQ',
    'title': 'عنوان',
    'url': canonical,
    'status': 'finished',
    'filename': ?filename,
  };

  DownloadEngine makeEngine(
    FakeApi api, {
    DeletePolicy policy = DeletePolicy.autoDelete,
    int maxPollAttempts = 5,
    void Function(DownloadTask)? onCompleted,
    bool Function()? compatibleVideo,
  }) => DownloadEngine(
    api: api,
    policy: policy,
    maxPollAttempts: maxPollAttempts,
    pollInterval: Duration.zero,
    savePathBuilder: (task, serverFilename) =>
        '${tempDir.path}${Platform.pathSeparator}${buildLocalFilename('عنوان', serverFilename: serverFilename)}',
    transfer: Transfer(api: api, backoff: const [Duration.zero, Duration.zero]),
    shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
    onCompleted: onCompleted,
    compatibleVideo: compatibleVideo,
  );

  Future<DownloadTask> awaitFinished(DownloadEngine engine, String taskId) =>
      engine.updates
          .firstWhere((t) => t.id == taskId && t.isFinished)
          .timeout(const Duration(seconds: 5));

  group('DownloadEngine: the four-stage pipeline', () {
    // **Playback compatibility is asked at add time** (field report
    // 2026-09-03), like `pullGate`: a point-in-time read, so changing the
    // setting needs no rebuild.
    test(
      'compatibleVideo reaches api.add exactly as the gate reports it',
      () async {
        for (final answer in [true, false]) {
          final api = FakeApi(
            historyScript: [
              historyWith(),
              historyWith(done: [doneItem()]),
            ],
          );
          final engine = makeEngine(api, compatibleVideo: () => answer);
          final task = engine.submit(canonical, Quality.best);
          await awaitFinished(engine, task.id);
          expect(api.lastCompatibleVideo, answer);
          await engine.dispose();
        }
      },
    );

    test('with no compatibility gate it is false, the behaviour from before the change', () async {
      final api = FakeApi(
        historyScript: [
          historyWith(),
          historyWith(done: [doneItem()]),
        ],
      );
      final engine = makeEngine(api);
      final task = engine.submit(canonical, Quality.best);
      await awaitFinished(engine, task.id);
      expect(api.lastCompatibleVideo, isFalse);
      await engine.dispose();
    });

    test("a full success under Lite's policy: add, poll, pull, then delete by the canonical URL", () async {
      final api = FakeApi(
        historyScript: [
          historyWith(), // the snapshot from before the add (defect ح-3)
          historyWith(
            queue: [
              {'url': canonical, 'status': 'downloading', 'percent': 40},
            ],
          ),
          historyWith(done: [doneItem()]),
        ],
      );
      final completed = <DownloadTask>[];
      final engine = makeEngine(api, onCompleted: completed.add);

      final task = engine.submit(inputUrl, Quality.q720);
      final result = await awaitFinished(engine, task.id);

      expect(result.phase, TaskPhase.completed);
      expect(api.adds.single.$1, inputUrl);
      expect(
        result.canonicalUrl,
        canonical,
        reason: 'المُقنون من /history لا المُدخل',
      );
      expect(api.deletes.single.$1, [canonical]);
      expect(api.deletes.single.$2, 'done');
      expect(File(result.localPath!).existsSync(), isTrue);
      expect(completed.single.id, task.id);
    });

    test("Super's mode, with pullToDevice false, completes with no pull and no delete", () async {
      final api = FakeApi(
        historyScript: [
          historyWith(),
          historyWith(done: [doneItem()]),
        ],
      );
      final engine = DownloadEngine(
        api: api,
        policy: DeletePolicy.keepOnServer,
        pullToDevice: false,
        pollInterval: Duration.zero,
        savePathBuilder: (t, f) => throw StateError('لا مسار في وضع السيرفر'),
        shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
      );
      final task = engine.submit(inputUrl, Quality.best);
      final result = await awaitFinished(engine, task.id);
      expect(result.phase, TaskPhase.completed);
      expect(result.canonicalUrl, canonical);
      expect(result.serverFilename, isNotNull);
      expect(result.localPath, isNull);
      expect(api.downloadCalls, 0);
      expect(api.deletes, isEmpty);
    });

    test("Super's keepOnServer policy: no delete after a pull", () async {
      final api = FakeApi(
        historyScript: [
          historyWith(),
          historyWith(done: [doneItem()]),
        ],
      );
      final engine = makeEngine(api, policy: DeletePolicy.keepOnServer);
      final task = engine.submit(inputUrl, Quality.best);
      final result = await awaitFinished(engine, task.id);
      expect(result.phase, TaskPhase.completed);
      expect(api.deletes, isEmpty);
    });

    test(
      'a server error during polling fails immediately, and classified',
      () async {
        final api = FakeApi(
          historyScript: [
            historyWith(),
            historyWith(
              queue: [
                {
                  'url': canonical,
                  'status': 'error',
                  'msg': 'Sign in to confirm you are not a bot',
                },
              ],
            ),
          ],
        );
        final engine = makeEngine(api);
        final task = engine.submit(inputUrl, Quality.best);
        final result = await awaitFinished(engine, task.id);
        expect(result.phase, TaskPhase.failed);
        expect(result.error, isA<PlatformBlockedException>());
        expect(
          api.historyCalls,
          2,
          reason: 'لقطة + استطلاع واحد — لا انتظار الـ10 دقائق',
        );
      },
    );

    test(
      'a missing filename in done waits rather than inventing one',
      () async {
        final api = FakeApi(
          historyScript: [
            historyWith(),
            historyWith(done: [doneItem(filename: null)]),
            historyWith(done: [doneItem(filename: null)]),
            historyWith(done: [doneItem()]),
          ],
        );
        final engine = makeEngine(api);
        final task = engine.submit(inputUrl, Quality.best);
        final result = await awaitFinished(engine, task.id);
        expect(result.phase, TaskPhase.completed);
        expect(api.historyCalls, 4);
      },
    );

    test('running out of poll attempts raises PollTimeoutException', () async {
      final api = FakeApi(historyScript: [historyWith()]);
      final engine = makeEngine(api, maxPollAttempts: 3);
      final task = engine.submit(inputUrl, Quality.best);
      final result = await awaitFinished(engine, task.id);
      expect(result.phase, TaskPhase.failed);
      expect(result.error, isA<PollTimeoutException>());
      expect(api.historyCalls, 4, reason: 'لقطة + 3 محاولات');
    });

    test('cancelling a queued task before it starts gives cancelled, with no request at all', () async {
      final api = FakeApi(
        historyScript: [
          historyWith(),
          historyWith(done: [doneItem()]),
        ],
      );
      final gate = Completer<void>();
      api.beforeAdd = () => gate.future;
      final engine = makeEngine(api);

      final first = engine.submit(inputUrl, Quality.best);
      final second = engine.submit('https://vimeo.com/76979871', Quality.best);
      engine.cancel(second.id);
      gate.complete();

      final firstResult = await awaitFinished(engine, first.id);
      expect(firstResult.phase, TaskPhase.completed);
      expect(engine.taskById(second.id)!.phase, TaskPhase.cancelled);
      expect(api.adds, hasLength(1), reason: 'الملغاة لم تصل للسيرفر');
    });

    test('cancelling during polling gives cancelled', () async {
      final api = FakeApi(historyScript: [historyWith()]);
      final engine = makeEngine(api, maxPollAttempts: 1000);
      final task = engine.submit(inputUrl, Quality.best);
      api.onHistoryFetch = (call) {
        if (call == 3) engine.cancel(task.id);
      };
      final result = await awaitFinished(engine, task.id);
      expect(result.phase, TaskPhase.cancelled);
    });

    test("the server's progress during polling reaches the stream", () async {
      final api = FakeApi(
        historyScript: [
          historyWith(),
          historyWith(
            queue: [
              {'url': canonical, 'status': 'downloading', 'percent': 45.3},
            ],
          ),
          historyWith(done: [doneItem()]),
        ],
      );
      final engine = makeEngine(api);
      final seen = <double>[];
      final sub = engine.updates.listen((t) => seen.add(t.progress));
      final task = engine.submit(inputUrl, Quality.best);
      await awaitFinished(engine, task.id);
      await sub.cancel();
      expect(seen, contains(closeTo(0.453, 0.0001)));
    });

    // **The progress throttling guard** (field report 2026-09-04: "seven
    // downloads make the app heavy", and "the notification counter does not
    // move"). Dio calls `onReceiveProgress` on **every chunk**; without a
    // filter each chunk became an item in `updates`, rebuilding the library
    // and posting a notification per task. A thousand ticks must not exceed
    // 101 broadcasts, one per whole percentage.
    test(
      'a thousand pull ticks emit once per whole percent, no more',
      () async {
        final api = FakeApi(
          historyScript: [
            historyWith(),
            historyWith(done: [doneItem()]),
          ],
        )..fineProgressTicks = 1000;
        final engine = makeEngine(api);
        final pulls = <double>[];
        final sub = engine.updates
            .where((t) => t.phase == TaskPhase.pulling)
            .listen((t) => pulls.add(t.progress));
        final task = engine.submit(inputUrl, Quality.best);
        await awaitFinished(engine, task.id);
        await sub.cancel();

        // 101 whole percentages plus two broadcasts that are not progress:
        // the start of the phase (`progress: 0`) and recording `localPath`
        // after the transfer succeeds.
        expect(
          pulls.length,
          lessThanOrEqualTo(103),
          reason: 'التقدّم يُبَثّ عند تغيّر النسبة الصحيحة فقط',
        );
        // And it is not throttled into silence: the progress genuinely
        // arrived from beginning to end.
        expect(pulls.length, greaterThan(50));
        expect(pulls.last, closeTo(1.0, 0.0001));
      },
    );

    /// The percentage resets with every phase, so the filter does not
    /// swallow **a new phase's progress** merely because the previous phase
    /// reached the same number.
    test(
      'the filter does not block a new phase reporting the same percentage',
      () async {
        final api = FakeApi(
          historyScript: [
            historyWith(),
            historyWith(
              queue: [
                {'url': canonical, 'status': 'downloading', 'percent': 100.0},
              ],
            ),
            historyWith(done: [doneItem()]),
          ],
        )..fineProgressTicks = 200;
        final engine = makeEngine(api);
        final pulling = <double>[];
        final sub = engine.updates
            .where((t) => t.phase == TaskPhase.pulling)
            .listen((t) => pulling.add(t.progress));
        final task = engine.submit(inputUrl, Quality.best);
        await awaitFinished(engine, task.id);
        await sub.cancel();
        // Polling reached 100% before the pull, and the pull still broadcast
        // its progress in full.
        expect(pulling.last, closeTo(1.0, 0.0001));
        expect(pulling.length, greaterThan(50));
      },
    );
  });
}
