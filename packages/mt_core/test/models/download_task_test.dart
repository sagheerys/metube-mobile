import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('DownloadTask', () {
    test('an automatic uuid, unique each time', () {
      final a = DownloadTask(inputUrl: 'u', quality: Quality.best);
      final b = DownloadTask(inputUrl: 'u', quality: Quality.best);
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(b.id));
    });

    test('copyWith keeps the identity and updates the phase', () {
      final task = DownloadTask(inputUrl: 'u', quality: Quality.audio);
      final updated = task.copyWith(
        phase: TaskPhase.polling,
        canonicalUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        progress: 0.5,
      );
      expect(updated.id, task.id);
      expect(updated.createdAt, task.createdAt);
      expect(updated.quality, Quality.audio);
      expect(updated.phase, TaskPhase.polling);
      expect(updated.progress, 0.5);
      expect(task.phase, TaskPhase.queued, reason: 'الأصل لا يتغير');
    });

    test('effectiveUrl prefers the resolved URL', () {
      final task = DownloadTask(
        inputUrl: 'https://vt.tiktok.com/xyz/',
        quality: Quality.best,
      );
      expect(task.effectiveUrl, 'https://vt.tiktok.com/xyz/');
      expect(
        task
            .copyWith(resolvedUrl: 'https://www.tiktok.com/@u/video/1')
            .effectiveUrl,
        'https://www.tiktok.com/@u/video/1',
      );
    });

    test('isFinished is true only for the terminal states', () {
      final task = DownloadTask(inputUrl: 'u', quality: Quality.best);
      expect(task.isFinished, isFalse);
      expect(task.copyWith(phase: TaskPhase.completed).isFinished, isTrue);
      expect(task.copyWith(phase: TaskPhase.failed).isFinished, isTrue);
      expect(task.copyWith(phase: TaskPhase.cancelled).isFinished, isTrue);
      expect(task.copyWith(phase: TaskPhase.pulling).isFinished, isFalse);
    });
  });

  /// The summary bar at the top of the library when several downloads run
  /// at once (field report 2026-09-03): a waiting task **counts as zero
  /// rather than being excluded**.
  group('averageTaskProgress', () {
    DownloadTask make(TaskPhase phase, double progress) => DownloadTask(
      inputUrl: 'u',
      quality: Quality.best,
    ).copyWith(phase: phase, progress: progress);

    test(
      'an empty list gives null',
      () => expect(averageTaskProgress(const []), isNull),
    );

    test('none with known progress gives null: an indeterminate bar', () {
      expect(
        averageTaskProgress([
          make(TaskPhase.queued, 0),
          make(TaskPhase.waitingForNetwork, 0.9),
        ]),
        isNull,
      );
    });

    test('a waiting task lowers the average rather than being excluded', () {
      // One at 90% and two queued gives 30%, not 90%.
      final average = averageTaskProgress([
        make(TaskPhase.pulling, 0.9),
        make(TaskPhase.queued, 0),
        make(TaskPhase.queued, 0),
      ]);
      expect(average, closeTo(0.3, 0.001));
    });

    test('an ordinary average', () {
      expect(
        averageTaskProgress([
          make(TaskPhase.polling, 0.25),
          make(TaskPhase.pulling, 0.75),
        ]),
        closeTo(0.5, 0.001),
      );
    });
  });
}
