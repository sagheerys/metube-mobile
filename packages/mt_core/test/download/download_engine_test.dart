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

  group('DownloadEngine — الخط الرباعي (§3)', () {
    // **توافق التشغيل يُسأل عند الإضافة** (بلاغ المالك 2026-09-03) —
    // كـ`pullGate`: قراءة لحظية فلا يحتاج تبديل الإعداد إعادة بناء.
    test('compatibleVideo يصل إلى api.add كما تقوله البوابة', () async {
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
    });

    test('بلا بوابة توافق ⇒ false (سلوك ما قبل التغيير)', () async {
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

    test(
      'نجاح كامل بسياسة Lite: add ← poll ← pull ← delete بالمُقنون',
      () async {
        final api = FakeApi(
          historyScript: [
            historyWith(), // لقطة ما قبل الإضافة (ح-3)
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
      },
    );

    test(
      'وضع Super (pullToDevice=false): يكتمل بلا سحب ولا حذف — ر-2',
      () async {
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
      },
    );

    test('سياسة Super (keepOnServer): لا حذف بعد السحب', () async {
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

    test('خطأ سيرفر أثناء الاستطلاع ⇒ فشل فوري مصنف (فخ §6.4)', () async {
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
    });

    test('filename غائب في done ⇒ ينتظر ولا يختلق (فخ §6.3)', () async {
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
    });

    test('انقضاء محاولات الاستطلاع ⇒ PollTimeoutException', () async {
      final api = FakeApi(historyScript: [historyWith()]);
      final engine = makeEngine(api, maxPollAttempts: 3);
      final task = engine.submit(inputUrl, Quality.best);
      final result = await awaitFinished(engine, task.id);
      expect(result.phase, TaskPhase.failed);
      expect(result.error, isA<PollTimeoutException>());
      expect(api.historyCalls, 4, reason: 'لقطة + 3 محاولات');
    });

    test('إلغاء مهمة منتظرة قبل بدئها ⇒ cancelled بلا أي طلب', () async {
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

    test('إلغاء أثناء الاستطلاع ⇒ cancelled', () async {
      final api = FakeApi(historyScript: [historyWith()]);
      final engine = makeEngine(api, maxPollAttempts: 1000);
      final task = engine.submit(inputUrl, Quality.best);
      api.onHistoryFetch = (call) {
        if (call == 3) engine.cancel(task.id);
      };
      final result = await awaitFinished(engine, task.id);
      expect(result.phase, TaskPhase.cancelled);
    });

    test('تقدم السيرفر أثناء polling يصل للبث', () async {
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

    // **حارس خنق بثّ التقدّم** (بلاغ المالك 2026-09-04: «سبعة تحميلات
    // ⇒ التطبيق ثقيل»، و«عدّاد الإشعارات لا يتحرك»). Dio ينادي
    // `onReceiveProgress` مع **كل قطعة**؛ بلا مرشّح كانت كل قطعة تصير
    // عنصراً في `updates` ⇒ إعادة بناء المكتبة ونشرَ إشعار لكل مهمة.
    // ألف نبضة يجب ألا تتجاوز 101 بثّة (نسبة صحيحة واحدة لكل قيمة).
    test('ألف نبضة سحب ⇒ بثّ واحد لكل نسبة صحيحة لا أكثر', () async {
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

      // 101 نسبة صحيحة + بثّتان ليستا تقدّماً: بداية الطور
      // (`progress: 0`) وتسجيل `localPath` بعد نجاح النقل.
      expect(
        pulls.length,
        lessThanOrEqualTo(103),
        reason: 'التقدّم يُبَثّ عند تغيّر النسبة الصحيحة فقط',
      );
      // ولا يُخنق حتى يختفي: التقدّم وصل فعلاً من أوله لآخره.
      expect(pulls.length, greaterThan(50));
      expect(pulls.last, closeTo(1.0, 0.0001));
    });

    /// النسبة تُصفَّر مع كل طور، فلا يبتلع المرشّحُ **تقدّمَ طورٍ جديد**
    /// لمجرد أن الطور السابق بلغ النسبة نفسها.
    test('المرشّح لا يمنع تقدّم طور جديد بنفس النسبة', () async {
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
      // بلغ الاستطلاع 100٪ قبل السحب — ومع ذلك السحب بثّ تقدّمه كاملاً.
      expect(pulling.last, closeTo(1.0, 0.0001));
      expect(pulling.length, greaterThan(50));
    });
  });
}
