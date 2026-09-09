import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// Defect tests from 2026-09-02. Every test here **fails before its fix**:
/// ح-3 (polling picks up an old item), ع-2 (a local error kills the
/// worker), ع-6 (a failed cleanup destroys a successful transfer), ع-7 (a
/// server orphan after cancellation).
void main() {
  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mtf_defects_');
  });
  tearDown(() async {
    // Windows refuses to delete a folder whose file is still open for a
    // moment after the transfer.
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tempDir.delete(recursive: true);
    }
  });

  const inputUrl = 'https://youtu.be/dQw4w9WgXcQ';
  const canonical = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

  Map<String, dynamic> doneItem({String filename = 'قناة.dQw4.mp4'}) => {
    'id': 'dQw4w9WgXcQ',
    'title': 'عنوان',
    'url': canonical,
    'status': 'finished',
    'filename': filename,
  };

  const secondUrl = 'https://youtu.be/aaaaaaaaaaa';
  Map<String, dynamic> secondItem() => {
    'id': 'aaaaaaaaaaa',
    'title': 'ثانٍ',
    'url': secondUrl,
    'status': 'finished',
    'filename': 'ثانٍ.mp4',
  };

  Map<String, dynamic> errorItem() => {
    'id': 'old',
    'url': canonical,
    'status': 'error',
    'msg': 'Sign in to confirm you are not a bot',
  };

  DownloadEngine makeEngine(
    FakeApi api, {
    DeletePolicy policy = DeletePolicy.autoDelete,
    SavePathBuilder? savePathBuilder,
    bool Function()? pullGate,
  }) => DownloadEngine(
    api: api,
    policy: policy,
    maxPollAttempts: 6,
    pollInterval: const Duration(milliseconds: 1),
    pullGate: pullGate,
    savePathBuilder:
        savePathBuilder ??
        (task, serverFilename) =>
            '${tempDir.path}${Platform.pathSeparator}'
            '${buildLocalFilename('عنوان', serverFilename: serverFilename)}',
    transfer: Transfer(api: api, backoff: const [Duration.zero, Duration.zero]),
    shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
  );

  Future<DownloadTask> awaitFinished(DownloadEngine engine, String taskId) =>
      engine.updates
          .firstWhere((t) => t.id == taskId && t.isFinished)
          .timeout(const Duration(seconds: 5));

  group('ح-3 — الاستطلاع لا ينسب لنفسه عنصراً سابقاً', () {
    test(
      'إعادة محاولة رابط فشل سابقاً: العنصر القديم لا يُفشِل الجديد',
      () async {
        final api = FakeApi(
          historyScript: [
            historyWith(
              done: [errorItem()],
            ), // the snapshot: the error existed before us
            historyWith(done: [errorItem()]), // unchanged, so it is ignored
            historyWith(
              done: [errorItem(), doneItem()],
            ), // our own operation completed
          ],
        );
        final engine = makeEngine(api);
        final task = engine.submit(inputUrl, Quality.best);
        final result = await awaitFinished(engine, task.id);

        expect(
          result.phase,
          TaskPhase.completed,
          reason: 'قبل الإصلاح كان يفشل فوراً من العنصر القديم',
        );
        expect(result.serverFilename, 'قناة.dQw4.mp4');
      },
    );

    test('جودة قديمة على السيرفر لا تُعلن نجاح طلب جديد', () async {
      final old = doneItem(filename: 'قناة.480.mp4');
      final api = FakeApi(
        historyScript: [
          historyWith(done: [old]), // 480 was already there
          historyWith(done: [old]),
          historyWith(done: [doneItem(filename: 'قناة.1080.mp4')]),
        ],
      );
      final engine = makeEngine(api, policy: DeletePolicy.keepOnServer);
      final task = engine.submit(inputUrl, Quality.q1080);
      final result = await awaitFinished(engine, task.id);

      expect(
        result.serverFilename,
        'قناة.1080.mp4',
        reason: 'قبل الإصلاح كان يسحب ملف 480 القديم',
      );
    });
  });

  test('ع-2 — خطأ محلي غير مصنف يُفشل مهمته ولا يجمّد الطابور', () async {
    final api = FakeApi(
      historyScript: [
        historyWith(), // the first one's snapshot
        historyWith(done: [doneItem()]), // completed on the server
        historyWith(done: [doneItem()]), // the second one's snapshot
        historyWith(done: [doneItem(), secondItem()]),
      ],
    );
    var first = true;
    final engine = makeEngine(
      api,
      savePathBuilder: (task, serverFilename) {
        if (first) {
          first = false;
          throw const FileSystemException('المجلد أُزيل');
        }
        return '${tempDir.path}${Platform.pathSeparator}ok.mp4';
      },
    );

    final a = engine.submit(inputUrl, Quality.best);
    final b = engine.submit(secondUrl, Quality.best);

    final aResult = await awaitFinished(engine, a.id);
    expect(aResult.phase, TaskPhase.failed);
    expect(aResult.error, isA<LocalFailureException>());

    final bResult = await awaitFinished(engine, b.id);
    expect(
      bResult.phase,
      TaskPhase.completed,
      reason: 'قبل الإصلاح كان الطابور كله يتجمد خلف الأولى',
    );
  });

  test('ع-6 — فشل تنظيف السيرفر لا يطيح بسحب ناجح', () async {
    final api = FakeApi(
      historyScript: [
        historyWith(),
        historyWith(done: [doneItem()]),
      ],
    )..deleteError = const ServerErrorException('العنصر غير موجود');
    final completed = <DownloadTask>[];
    final engine = DownloadEngine(
      api: api,
      policy: DeletePolicy.autoDelete,
      maxPollAttempts: 6,
      pollInterval: const Duration(milliseconds: 1),
      savePathBuilder: (t, f) =>
          '${tempDir.path}${Platform.pathSeparator}file.mp4',
      transfer: Transfer(
        api: api,
        backoff: const [Duration.zero, Duration.zero],
      ),
      shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
      onCompleted: completed.add,
    );

    final task = engine.submit(inputUrl, Quality.best);
    final result = await awaitFinished(engine, task.id);

    expect(result.phase, TaskPhase.completed);
    expect(result.localPath, isNotNull);
    expect(
      completed,
      hasLength(1),
      reason: 'الفهرسة يجب أن تقع — الملف على القرص فعلاً',
    );
  });

  test('ع-7 — الإلغاء أثناء الاستطلاع يكنس يتيم السيرفر', () async {
    final api = FakeApi(
      historyScript: [
        historyWith(), // an empty snapshot
        historyWith(
          queue: [
            {'url': canonical, 'status': 'downloading', 'percent': 10},
          ],
        ),
      ],
    );
    final engine = makeEngine(api);
    final task = engine.submit(inputUrl, Quality.best);
    api.onHistoryFetch = (call) {
      if (call == 1) engine.cancel(task.id);
    };

    final result = await awaitFinished(engine, task.id);
    expect(result.phase, TaskPhase.cancelled);
    // The sweep is asynchronous, so we wait a short event loop.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      api.deletes,
      hasLength(1),
      reason: 'ما أضفناه ثم ألغيناه لا يُترك على السيرفر',
    );
    expect(api.deletes.single.$2, 'queue');
  });

  test('ع-7 — الكنس لا يمسّ عنصراً كان موجوداً قبل المهمة', () async {
    final api = FakeApi(
      historyScript: [
        historyWith(done: [doneItem()]), // existed before us
        historyWith(done: [doneItem()]),
      ],
    );
    final engine = makeEngine(api);
    final task = engine.submit(inputUrl, Quality.best);
    api.onHistoryFetch = (call) {
      if (call == 1) engine.cancel(task.id);
    };

    await awaitFinished(engine, task.id);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(api.deletes, isEmpty);
  });

  test('م-10 — مهمة محجوزة بالبوابة لا توقف التالية عنها', () async {
    var gateOpen = false;
    final api = FakeApi(
      historyScript: [
        historyWith(),
        historyWith(done: [doneItem()]),
        historyWith(done: [doneItem()]), // the second one's snapshot
        historyWith(done: [doneItem(), secondItem()]),
      ],
    );
    final engine = makeEngine(
      api,
      policy: DeletePolicy.keepOnServer,
      pullGate: () => gateOpen,
    );

    final blocked = engine.submit(inputUrl, Quality.best);
    await engine.updates.firstWhere(
      (t) => t.id == blocked.id && t.phase == TaskPhase.waitingForNetwork,
    );

    // The second passes through the server even though the first is still
    // waiting on the network.
    final second = engine.submit(secondUrl, Quality.best);
    await engine.updates
        .firstWhere(
          (t) => t.id == second.id && t.phase == TaskPhase.waitingForNetwork,
        )
        .timeout(const Duration(seconds: 5));
    expect(
      api.adds,
      hasLength(2),
      reason: 'قبل الإصلاح كان العامل واقفاً على المحجوزة',
    );

    gateOpen = true;
    final result = await awaitFinished(engine, blocked.id);
    expect(result.phase, TaskPhase.completed);
    await awaitFinished(engine, second.id);
    await engine.dispose(); // stops the gate tick before the temporary folder is deleted
  });

  test('ع-1 — التصريف يكسر حلقة الاستطلاع ولا يبثّ في stream مغلق', () async {
    final api = FakeApi(historyScript: [historyWith()]);
    final engine = DownloadEngine(
      api: api,
      policy: DeletePolicy.keepOnServer,
      pullToDevice: false,
      maxPollAttempts: 100000,
      pollInterval: const Duration(milliseconds: 1),
      savePathBuilder: (t, f) => '${tempDir.path}/x',
      shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
    );
    engine.submit(inputUrl, Quality.best);
    await engine.updates.firstWhere((t) => t.phase == TaskPhase.polling);

    await engine.dispose();
    final callsAtDispose = api.historyCalls;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(
      api.historyCalls,
      lessThanOrEqualTo(callsAtDispose + 1),
      reason: 'الحلقة كانت تدور للأبد بعد التصريف',
    );
  });
}
