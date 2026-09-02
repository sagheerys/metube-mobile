import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// م-42 «Wi‑Fi فقط» + م-43 «قابلية إعادة المحاولة».
void main() {
  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mtf_gate_');
  });
  tearDown(() => tempDir.delete(recursive: true));

  const canonical = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
  const inputUrl = 'https://youtu.be/jNQXAC9IVRw';

  FakeApi apiWithDone() => FakeApi(historyScript: [
        historyWith(done: [
          {
            'id': 'jNQXAC9IVRw',
            'title': 'عنوان',
            'url': canonical,
            'status': 'finished',
            'filename': 'clip.mp4',
          }
        ]),
      ]);

  DownloadEngine build(FakeApi api, {bool Function()? gate}) => DownloadEngine(
        api: api,
        policy: DeletePolicy.keepOnServer,
        maxPollAttempts: 5,
        pollInterval: const Duration(milliseconds: 5),
        savePathBuilder: (task, filename) =>
            '${tempDir.path}${Platform.pathSeparator}$filename',
        transfer:
            Transfer(api: api, backoff: const [Duration.zero, Duration.zero]),
        shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
        pullGate: gate,
      );

  group('بوابة السحب (م-42)', () {
    test('بلا بوابة: يسحب مباشرة ولا يمر بـ waitingForNetwork', () async {
      final engine = build(apiWithDone());
      final phases = <TaskPhase>[];
      engine.updates.listen((t) => phases.add(t.phase));
      final task = engine.submit(inputUrl, Quality.best);
      final result = await engine.updates
          .firstWhere((t) => t.id == task.id && t.isFinished)
          .timeout(const Duration(seconds: 5));

      expect(result.phase, TaskPhase.completed);
      expect(phases, isNot(contains(TaskPhase.waitingForNetwork)));
    });

    test('بوابة مغلقة: ينتظر بلا فشل — ثم يكمل حين تُفتح', () async {
      var allowed = false;
      final engine = build(apiWithDone(), gate: () => allowed);
      final phases = <TaskPhase>[];
      engine.updates.listen((t) => phases.add(t.phase));
      final task = engine.submit(inputUrl, Quality.best);

      await _tick(30);
      // **الانتظار حالة مشروعة**: لا اكتمال ولا فشل ما دامت البوابة مغلقة.
      expect(phases.last, TaskPhase.waitingForNetwork);
      expect(phases, isNot(contains(TaskPhase.completed)));
      expect(phases, isNot(contains(TaskPhase.failed)));

      allowed = true;
      final result = await engine.updates
          .firstWhere((t) => t.id == task.id && t.isFinished)
          .timeout(const Duration(seconds: 5));
      expect(result.phase, TaskPhase.completed);
    });

    test('الإلغاء يكسر الانتظار — لا حلقة أبدية', () async {
      final engine = build(apiWithDone(), gate: () => false);
      final phases = <TaskPhase>[];
      engine.updates.listen((t) => phases.add(t.phase));
      final task = engine.submit(inputUrl, Quality.best);

      await _tick(30);
      expect(phases.last, TaskPhase.waitingForNetwork);

      engine.cancel(task.id);
      final result = await engine.updates
          .firstWhere((t) => t.id == task.id && t.isFinished)
          .timeout(const Duration(seconds: 5));
      expect(result.phase, TaskPhase.cancelled);
    });
  });

  group('isRetryable (م-43) — عطل الطريق لا رفض الوجهة', () {
    test('الشبكة والمهلة تُعادان', () {
      expect(const NetworkException().isRetryable, isTrue);
      expect(const PollTimeoutException().isRetryable, isTrue);
    });

    test('رفض السيرفر والاعتماد والحظر لا تُعاد', () {
      expect(const AuthFailureException().isRetryable, isFalse);
      expect(const ServerErrorException('boom').isRetryable, isFalse);
      expect(const PlatformBlockedException('login').isRetryable, isFalse);
      expect(const CancelledException().isRetryable, isFalse);
      expect(const UnsafeFilenameException().isRetryable, isFalse);
    });
  });
}

Future<void> _tick(int times) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
